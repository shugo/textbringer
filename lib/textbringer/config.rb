module Textbringer
  CONFIG = {
    east_asian_ambiguous_width: 1,
    default_file_encoding: Encoding::UTF_8,
    default_file_format: :unix,
    tab_width: 8,
    indent_tabs_mode: false,
    case_fold_search: true,
    buffer_dump_dir: File.expand_path("~/.textbringer/buffer_dump"),
    mark_ring_max: 16,
    global_mark_ring_max: 16,
    window_min_height: 4,
    syntax_highlight: true,
    highlight_buffer_size_limit: 1024,
    shell_file_name: ENV["SHELL"],
    shell_command_switch: "-c",
    grep_command: "grep -nH -e",
    fill_column: 70,
    read_file_name_completion_ignore_case: RUBY_PLATFORM.match?(/darwin/),
    default_input_method: "t_code"
  }
end
