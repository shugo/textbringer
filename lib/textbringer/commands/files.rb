require "editorconfig"

module Textbringer
  module Commands
    define_command(:find_file, doc: "Open or create a file.") do
      |file_name = read_file_name("Find file: ", default: (Buffer.current.file_name ? File.dirname(Buffer.current.file_name) : Dir.pwd) + "/")|
      config = EditorConfig.load_file(file_name)
      buffer = Buffer.find_file(file_name)
      if buffer.new_file?
        message("New file")
      end
      switch_to_buffer(buffer)
      shebang = buffer.save_excursion {
        buffer.beginning_of_buffer
        buffer.looking_at?(/#!.*$/) ? buffer.match_string(0) : nil
      }
      mode = Mode.list.find { |m|
        (m.file_name_pattern &&
         m.file_name_pattern =~ File.basename(buffer.file_name)) ||
          (m.interpreter_name_pattern &&
           m.interpreter_name_pattern =~ shebang)
      } || FundamentalMode
      send(mode.command_name)
      if config.key?("charset")
        Buffer.current.file_encoding = config["charset"]
      end
      if config.key?("end_of_line")
        Buffer.current.file_format =
          case config["end_of_line"]
          when "lf"
            :unix
          when "crlf"
            :dos
          when "cr"
            :mac
          end
      end
      if config.key?("indent_style")
        Buffer.current[:indent_tabs_mode] = config["indent_style"] == "tab"
      end
      if config.key?("indent_size")
        Buffer.current[:indent_level] = config["indent_size"].to_i
      end
      if config.key?("tab_width")
        Buffer.current[:tab_width] = config["tab_width"].to_i
      end
    end

    define_command(:revert_buffer, doc: <<~EOD) do
      Revert the contents of the current buffer from the file on disk.
    EOD
      unless yes_or_no?("Revert buffer from file?")
        message("Cancelled")
        next
      end
      Buffer.current.revert
    end

    define_command(:revert_buffer_with_encoding, doc: <<~EOD) do
      Revert the contents of the current buffer from the file on disk
      using the specified encoding.
      If the specified encoding is not valid, fall back to ASCII-8BIT.
    EOD
      |encoding = read_encoding("File encoding: ")|
      unless yes_or_no?("Revert buffer from file?")
        message("Cancelled")
        next
      end
      Buffer.current.revert(encoding)
    end

    define_command(:save_buffer, doc: "Save the current buffer to a file.") do
      if Buffer.current.file_name.nil?
        Buffer.current.file_name = read_file_name("File to save in: ")
        next if Buffer.current.file_name.nil?
      end
      if Buffer.current.file_modified?
        unless yes_or_no?("File changed on disk.  Save anyway?")
          message("Cancelled")
          next
        end
      end
      Buffer.current.save
      message("Wrote #{Buffer.current.file_name}")
    end

    define_command(:write_file,
                   doc: "Save the current buffer as the specified file.") do
      |file_name = read_file_name("Write file: ")|
      if File.directory?(file_name)
        file_name = File.expand_path(Buffer.current.name, file_name)
      end
      if File.exist?(file_name)
        unless y_or_n?("File `#{file_name}' exists; overwrite?")
          message("Cancelled")
          next
        end
      end
      Buffer.current.save(file_name)
      message("Wrote #{Buffer.current.file_name}")
    end

    define_command(:set_buffer_file_encoding,
                   doc: "Set the file encoding of the current buffer.") do
      |enc = read_encoding("File encoding: ",
                           default: Buffer.current.file_encoding.name)|
      Buffer.current.file_encoding = enc
    end

    define_command(:set_buffer_file_format,
                   doc: "Set the file format of the current buffer.") do
      |format = read_from_minibuffer("File format: ",
                                     default: Buffer.current.file_format.to_s)|
      Buffer.current.file_format = format
    end

    define_command(:pwd, doc: "Show the current working directory.") do
      message(Dir.pwd)
    end

    define_command(:chdir, doc: "Change the current working directory.") do
      |dir_name = read_file_name("Change directory: ",
                                 default: Buffer.current.file_name &&
                                 File.dirname(Buffer.current.file_name))|
      Dir.chdir(dir_name)
    end

    define_command(:find_alternate_file, doc: "Find an alternate file.") do
      |file_name = read_file_name("Find alternate file: ",
                                  default: Buffer.current.file_name)|
      find_file(file_name)
    end
  end
end
