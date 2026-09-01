# source: main.rb
# frozen_string_literal: true


# source: lib/backend.rb
# frozen_string_literal: true

class SuiteBackend
  SCORE_LABEL = "aligned variables"
  STATUSES = ["open", "tending", "complete"].freeze
  MAX_ITEMS = 128
  MAX_HISTORY = 256
  MAX_TEXT = 512
  MAX_STATE_BYTES = 262_144
  OUTPUT_LIMIT = 65_536

  Result = Struct.new(:stdout, :stderr, :exitstatus) do
    def success? = exitstatus.to_i.zero?
  end

  attr_reader :records

  def initialize(state_dir: File.expand_path("~/.local/state/omarchy-env-bridge"), runner: nil)
    @state_dir = state_dir
    @state_path = File.join(state_dir, "state.json")
    @runner = runner
    @records = []
    @history = []
    @settings = {}
    @summary = "Starting"
    @score = 0
    create_directory(@state_dir)
    load_state
  end

  def snapshot
    {
      "items" => @records.first(MAX_ITEMS),
      "history" => @history.last(MAX_HISTORY),
      "summary" => clean(@summary, 100),
      "score" => @score.to_i,
      "updated_at" => Time.now.to_i
    }
  end

  def add(primary, secondary = "")
    title = clean(primary)
    detail = clean(secondary)
    return snapshot if title.empty?
    record = {
      "id" => "#{Time.now.to_i}-#{rand(1_000_000)}",
      "title" => title,
      "detail" => detail,
      "status" => STATUSES.first,
      "meta" => Time.now.strftime("%Y-%m-%d %H:%M")
    }
    after_add(record)
    @records.unshift(record)
    @records = @records.first(MAX_ITEMS)
    @score = @records.length
    @summary = "#{@records.length} #{SCORE_LABEL}"
    persist
    snapshot
  end

  def act(id)
    record = @records.find { |candidate| candidate["id"] == id.to_s }
    return snapshot unless record
    current = STATUSES.index(record["status"]) || 0
    record["status"] = STATUSES[(current + 1) % STATUSES.length]
    record["meta"] = "Updated #{Time.now.strftime("%Y-%m-%d %H:%M")}"
    persist
    snapshot
  end

  def remove(id)
    @records.reject! { |candidate| candidate["id"] == id.to_s }
    @score = @records.length
    @summary = @records.empty? ? "Ready" : "#{@records.length} #{SCORE_LABEL}"
    persist
    snapshot
  end

  def refresh
    scanned = scan_system
    @records = scanned if scanned.is_a?(Array)
    @records = @records.first(MAX_ITEMS)
    persist
    snapshot
  rescue StandardError => error
    @summary = "Needs attention"
    @records.unshift(item("Refresh issue", clean(error.message, 180), "inspect", "No system state was changed"))
    @records = @records.first(MAX_ITEMS)
    snapshot
  end

  private

  def after_add(record)
    record["status"] = STATUSES.first
    record
  end

  def scan_system
    manager = {}
    command_text(["systemctl", "--user", "show-environment"]).lines.each do |line|
      key, value = line.strip.split("=", 2)
      if value && value.start_with?("$'") && value.end_with?("'")
        value = value[2..-2]
      end
      manager[key] = value if key && value
    end
    keys = %w[WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR PATH GTK_THEME QT_QPA_PLATFORM SDL_VIDEODRIVER MOZ_ENABLE_WAYLAND ELECTRON_OZONE_PLATFORM_HINT]
    rows = keys.map do |key|
      plugin_value = clean(ENV.fetch(key, ""), 220)
      manager_value = clean(manager.fetch(key, ""), 220)
      status = if plugin_value.empty? && manager_value.empty?
        "absent"
      elsif plugin_value == manager_value
        "aligned"
      else
        "drift"
      end
      item(key, plugin_value.empty? ? "plugin: —" : "plugin: #{plugin_value}", status, manager_value.empty? ? "user manager: —" : "user manager: #{manager_value}")
    end
    @score = rows.count { |record| record["status"] == "aligned" }
    drift = rows.count { |record| record["status"] == "drift" }
    @summary = drift.zero? ? "Session aligned" : "#{drift} differences"
    rows
  end

  def item(title, detail, status = "observed", meta = "")
    {
      "id" => fnv1a("#{title}:#{detail}:#{status}"),
      "title" => clean(title), "detail" => clean(detail),
      "status" => clean(status, 80), "meta" => clean(meta, 240)
    }
  end

  def run(argv, timeout: 8)
    return @runner.call(argv, timeout: timeout) if @runner
    OmarchyUI::Command.run(argv, timeout: timeout, max_output_bytes: OUTPUT_LIMIT)
  rescue Errno::ENOENT, OmarchyUI::CommandTimeout, OmarchyUI::CommandOutputLimit
    nil
  end

  def command_text(argv, timeout: 8)
    result = run(argv, timeout: timeout)
    return "" unless result && result.success?
    clean(result.stdout.to_s, OUTPUT_LIMIT)
  end

  def parse_json(text)
    return nil if text.nil? || text.empty? || text.bytesize > OUTPUT_LIMIT
    JSON.parse(text)
  rescue JSON::ParserError
    nil
  end

  def clean(value, limit = MAX_TEXT)
    value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�").byteslice(0, limit).to_s
  rescue StandardError
    value.to_s.byteslice(0, limit).to_s
  end

  def safe_read(path, limit = MAX_STATE_BYTES)
    flags = File::RDONLY | File::NOFOLLOW | File::BINARY
    File.open(path, flags) do |file|
      data = file.read(limit + 1)
      return nil if data && data.bytesize > limit
      data
    end
  rescue SystemCallError
    nil
  end


  def relative_files(root)
    return [] unless File.directory?(root)
    result = []
    queue = [[root, ""]]
    until queue.empty? || result.length >= 2_000
      absolute, relative = queue.shift
      Dir.children(absolute).sort.first(512).each do |entry|
        next if entry == ".git" || entry == "node_modules" || entry == "vendor"
        child = File.join(absolute, entry)
        rel = relative.empty? ? entry : File.join(relative, entry)
        if File.directory?(child) && !File.symlink?(child)
          queue << [child, rel]
        elsif File.file?(child)
          result << rel
        end
      rescue SystemCallError
        next
      end
    end
    result
  end

  def executable?(name)
    return false if name.to_s.include?(File::SEPARATOR)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      path = File.join(directory, name.to_s)
      File.respond_to?(:executable?) ? File.executable?(path) : File.file?(path)
    end
  end

  def secure_equal?(left, right)
    return false unless left.bytesize == right.bytesize
    difference = 0
    left.bytes.zip(right.bytes) { |a, b| difference |= a ^ b }
    difference.zero?
  end

  def fnv1a(value)
    hash = 2_166_136_261
    value.to_s.each_byte { |byte| hash = ((hash ^ byte) * 16_777_619) & 0xffff_ffff }
    format("%08x", hash)
  end

  def percent(part, whole)
    return 0 if whole.to_i <= 0
    [[(part.to_f / whole.to_f * 100).round, 0].max, 100].min
  end

  def human_bytes(bytes)
    value = bytes.to_f
    units = %w[B KiB MiB GiB TiB]
    unit = units.shift
    while value >= 1024 && !units.empty?
      value /= 1024.0
      unit = units.shift
    end
    "#{value.round(value >= 10 ? 0 : 1)} #{unit}"
  end

  def human_duration(seconds)
    days = seconds.to_f / 86_400
    return "#{days.round} days" if days < 365
    "#{(days / 365).round(1)} years"
  end

  def short_path(path)
    home = File.expand_path("~")
    path.start_with?(home) ? path.sub(home, "~") : path
  end

  def create_directory(path)
    current = path.start_with?(File::SEPARATOR) ? File::SEPARATOR : ""
    path.split(File::SEPARATOR).each do |part|
      next if part.empty?
      current = File.join(current, part)
      begin
        Dir.mkdir(current, 0o700)
      rescue Errno::EEXIST
        nil
      end
      symlink = File.respond_to?(:symlink?) && File.symlink?(current)
      raise "unsafe state directory" unless File.directory?(current) && !symlink
    end
    expanded = File.expand_path(path)
    raise "unsafe state directory" unless File.realpath(path) == expanded
    File.chmod(0o700, expanded)
  end

  def load_state
    data = safe_read(@state_path)
    return unless data
    parsed = data ? JSON.parse(data) : {}
    @records = Array(parsed["records"]).filter_map { |record| normalize_record(record) }.first(MAX_ITEMS)
    @history = Array(parsed["history"]).select { |entry| entry.is_a?(Hash) }.last(MAX_HISTORY)
    @settings = parsed["settings"].is_a?(Hash) ? parsed["settings"] : {}
    @score = @records.length
    @summary = @records.empty? ? "Ready" : "#{@records.length} #{SCORE_LABEL}"
  rescue JSON::ParserError, SystemCallError
    @records = []; @history = []; @settings = {}
  end

  def normalize_record(record)
    return nil unless record.is_a?(Hash)
    title = clean(record["title"])
    return nil if title.empty?
    {
      "id" => clean(record["id"], 80), "title" => title,
      "detail" => clean(record["detail"]), "status" => clean(record["status"], 80),
      "meta" => clean(record["meta"], 240), "evidence" => record["evidence"].is_a?(Hash) ? record["evidence"] : nil
    }.compact
  end

  def persist
    payload = JSON.generate("records" => @records.first(MAX_ITEMS), "history" => @history.last(MAX_HISTORY), "settings" => @settings)
    raise "state exceeds safety limit" if payload.bytesize > MAX_STATE_BYTES
    flags = File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW
    temporary = nil
    10.times do
      temporary = "#{@state_path}.tmp-#{Process.pid}-#{rand(1_000_000)}"
      begin
        File.open(temporary, flags, 0o600) do |file|
          file.write(payload)
          file.flush
          file.fsync if file.respond_to?(:fsync)
        end
        break
      rescue Errno::EEXIST
        temporary = nil
      end
    end
    raise "could not allocate private state file" unless temporary
    File.rename(temporary, @state_path)
    File.chmod(0o600, @state_path)
  ensure
    File.delete(temporary) if temporary && File.file?(temporary)
  end
end


backend = SuiteBackend.new

OmarchyUI.plugin do
  state :snapshot, backend.snapshot
  state :primary, ""
  state :secondary, ""
  state :compose, false
  state :page, 0
  state :selected_plugin, ""

  refresh = proc do
    state.snapshot = backend.refresh
  rescue StandardError
    state.snapshot = backend.snapshot
  end

  status_color = lambda do |status|
    value = status.to_s.downcase
    danger = false
    healthy = false
    %w[broken critical missing mismatch drift inactive slow tight risk invalid attention].each do |token|
      danger = true if value.include?(token)
    end
    %w[ready valid verified finished aligned unique internal familiar steady covered available detected normal active loaded].each do |token|
      healthy = true if value.include?(token)
    end
    if danger
      "#ff6b78"
    elsif healthy
      "#7da7ff"
    else
      "#efc66b"
    end
  end

  status_icon = lambda do |status|
    value = status.to_s.downcase
    danger = false
    healthy = false
    %w[broken critical missing mismatch drift inactive slow tight risk invalid attention].each do |token|
      danger = true if value.include?(token)
    end
    %w[ready valid verified finished aligned unique internal familiar steady covered available detected normal active loaded].each do |token|
      healthy = true if value.include?(token)
    end
    if danger
      :warning
    elsif healthy
      :circle_check
    else
      :circle_info
    end
  end

  first_number = lambda do |value|
    number = 0
    value.to_s.split.each do |token|
      candidate = token.to_i
      if candidate > 0
        number = candidate
        break
      end
    end
    number
  end

  bar_widget do
    row spacing: 6 do
      icon :link, size: 14, color: "#7dcfff"
      text "ENV", style: :caption, color: "#7dcfff"
      text(style: :caption) { state.snapshot.fetch("summary") }
    end
    on_click { open_panel :env_bridge }
  end

  panel :env_bridge do
    scroll width: 660, height: 780 do
      dynamic id: :scene, spacing: 16 do
        entries = state.snapshot.fetch("items")
        drift = entries.count { |entry| entry.fetch("status", "") == "drift" }
        aligned = entries.count { |entry| entry.fetch("status", "") == "aligned" }
        absent = entries.count { |entry| entry.fetch("status", "") == "absent" }

        column spacing: 2 do
          text "#{aligned} variables cross the session boundary cleanly", style: :caption, width: 610
          row spacing: 9 do
            text "Env", size: 30, bold: true
            icon :link, size: 22, color: "#7dcfff"
            text "Bridge", size: 30, bold: true, width: 475
            action_button :refresh, tooltip: "Retest environment", foreground: "#7dcfff" do
              async(&refresh)
            end
          end
        end

        separator
        row spacing: 0 do
          column spacing: 3 do
            text "PLUGIN SESSION", style: :caption, color: "#7dcfff"
            text "●━━━━━━━━━━━━━━━━━━", size: 18, color: "#7dcfff"
          end
          column spacing: 3 do
            text "BOUNDARY", style: :caption, color: "#829088"
            icon :link, size: 26, color: drift.zero? ? "#d8ff73" : "#ff8b8b"
          end
          column spacing: 3 do
            text "SYSTEMD USER", style: :caption, color: "#7dcfff"
            text "━━━━━━━━━━━━━━━━━━●", size: 18, color: "#7dcfff"
          end
        end
        row spacing: 46 do
          column spacing: 0 do
            text aligned.to_s.rjust(2, "0"), size: 34, bold: true, color: "#d8ff73"
            text "ALIGNED", style: :caption
          end
          column spacing: 0 do
            text drift.to_s.rjust(2, "0"), size: 34, bold: true,
                 color: drift.zero? ? "#829088" : "#ff8b8b"
            text "DRIFT", style: :caption
          end
          column spacing: 0 do
            text absent.to_s.rjust(2, "0"), size: 34, bold: true, color: "#829088"
            text "ABSENT", style: :caption
          end
        end
        separator
        row spacing: 10 do
          text "ENVIRONMENT SPANS", size: 12, bold: true, color: "#7dcfff", width: 450
          text "PLUGIN  ⇄  MANAGER", style: :caption, color: "#829088"
        end

        entries.each_with_index do |entry, index|
          plugin_value = entry.fetch("detail", "").sub("plugin: ", "")
          manager_value = entry.fetch("meta", "").sub("user manager: ", "")
          plugin_value = plugin_value.byteslice(0, 76).to_s + "…" if plugin_value.bytesize > 79
          manager_value = manager_value.byteslice(0, 76).to_s + "…" if manager_value.bytesize > 79
          status = entry.fetch("status", "")
          bridge_color = status == "aligned" ? "#d8ff73" : (status == "drift" ? "#ff8b8b" : "#829088")
          column spacing: 4 do
            row spacing: 10 do
              text entry.fetch("title"), width: 455, size: 16, bold: true, color: bridge_color
              text status.upcase, style: :caption, color: bridge_color, width: 105
            end
            row spacing: 8 do
              text "PLUGIN", style: :caption, color: "#7dcfff", width: 62
              text plugin_value, style: :caption, width: 490, wrap: true
            end
            text "       ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●", style: :caption, color: bridge_color
            row spacing: 8 do
              text "SYSTEMD", style: :caption, color: "#7dcfff", width: 62
              text manager_value, style: :caption, width: 490, wrap: true
            end
          end
          separator unless index == entries.length - 1
        end
      end
    end
  end

  after(0.08, &refresh)
  every(45, &refresh)
end
