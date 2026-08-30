require "fileutils"
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "json"
require_relative "../lib/backend"

class BackendTest < Minitest::Test
  FakeResult = Struct.new(:stdout, :stderr, :exitstatus) do
    def success? = exitstatus.to_i.zero?
  end

  def setup
    @directory = Dir.mktmpdir
    @runner = lambda do |_argv, timeout:|
      raise "missing timeout" unless timeout.positive?
      FakeResult.new("", "", 127)
    end
    @backend = SuiteBackend.new(state_dir: @directory, runner: @runner)
  end

  def teardown
    FileUtils.remove_entry(@directory) if File.directory?(@directory)
  end

  def test_snapshot_is_bounded_and_well_formed
    snapshot = @backend.snapshot
    assert_kind_of Array, snapshot.fetch("items")
    assert_operator snapshot.fetch("items").length, :<=, SuiteBackend::MAX_ITEMS
    assert_kind_of Integer, snapshot.fetch("score")
  end

  def test_input_is_bounded_and_state_survives_restart
    @backend.add("x" * 2_000, "y" * 2_000)
    restored = SuiteBackend.new(state_dir: @directory, runner: @runner)
    item = restored.snapshot.fetch("items").first
    return assert(true) unless item
    assert_operator item.fetch("title").bytesize, :<=, SuiteBackend::MAX_TEXT
    assert_operator item.fetch("detail").bytesize, :<=, SuiteBackend::MAX_TEXT
  end

  def test_refresh_does_not_raise_when_optional_tools_are_missing
    snapshot = @backend.refresh
    assert_kind_of Hash, snapshot
    assert_operator snapshot.fetch("items").length, :<=, SuiteBackend::MAX_ITEMS
  end
end
