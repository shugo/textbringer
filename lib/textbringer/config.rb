# frozen_string_literal: true

module Textbringer
  CONFIG = {
    east_asian_ambiguous_width: 1,
    default_file_encoding: Encoding::UTF_8,
    default_file_format: :unix,
    tab_width: 8,
    indent_tabs_mode: false,
    case_fold_search: true,
    buffer_dump_dir: File.expand_path("~/.textbringer/buffer_dump")
  }
end
