# frozen_string_literal: true

module Textbringer
  CONFIG = {
    east_asian_ambiguous_width: 1,
    default_file_encoding: Encoding::UTF_8,
    default_file_format: :unix,
    tab_width: 8,
    indent_tabs_mode: false,
    case_fold_search: true,
    buffer_dump_dir: File.expand_path("~/.textbringer/buffer_dump"),
    tag_mark_limit: 16,
    window_min_height: 4,
    syntax_highlight: true,
    highlight_buffer_size_limit: 102400,
    shell_file_name: ENV["SHELL"],
    shell_command_switch: "-c",
    grep_command: "grep -nH -e"
  }
end
