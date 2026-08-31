# frozen_string_literal: true

OmarchyUI.configure do
  type :plugin
  id "izeesoft.env-bridge"
  name "Env Bridge"
  slug "env-bridge"
  version "0.1.0"
  author "Adam Moussa Ali"
  license "MIT"
  description "Safe environment-variable drift inspector for interactive and systemd user sessions."
  entrypoint "main.rb"

  bar_widget do
    display_name "Env Bridge"
    description "Compare the environment seen by desktop apps with the systemd user manager."
    category "Developer Tools"
    default_section :right
  end
end
