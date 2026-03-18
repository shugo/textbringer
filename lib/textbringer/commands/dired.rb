require "fileutils"

module Textbringer
  module Commands
    define_command(:dired, doc: "Open a directory browser.") do
      |dir = read_file_name("Dired: ",
                            default: (Buffer.current.file_name ?
                              File.dirname(Buffer.current.file_name) : Dir.pwd) + "/")|
      dir = File.expand_path(dir)
      raise EditorError, "#{dir} is not a directory" unless File.directory?(dir)
      buf_name = "*Dired: #{dir}*"
      buffer = Buffer.find_or_new(buf_name, undo_limit: 0, read_only: true)
      buffer[:dired_directory] = dir
      buffer.apply_mode(DiredMode) unless buffer.mode.is_a?(DiredMode)
      if buffer.bytesize == 0
        buffer.read_only_edit do
          buffer.insert(DiredMode.generate_listing(dir))
          buffer.beginning_of_buffer
          buffer.forward_line
        end
      end
      switch_to_buffer(buffer)
      dired_move_to_filename_command
    end
  end
end
