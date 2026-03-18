module Textbringer
  class DiredMode < Mode
    define_keymap :DIRED_MODE_MAP
    DIRED_MODE_MAP.define_key("n",    :dired_next_line_command)
    DIRED_MODE_MAP.define_key(" ",    :dired_next_line_command)
    DIRED_MODE_MAP.define_key("p",    :dired_previous_line_command)
    DIRED_MODE_MAP.define_key("^",    :dired_up_directory_command)
    DIRED_MODE_MAP.define_key("\C-m", :dired_find_file_command)
    DIRED_MODE_MAP.define_key("f",    :dired_find_file_command)
    DIRED_MODE_MAP.define_key("o",    :dired_find_file_other_window_command)
    DIRED_MODE_MAP.define_key("d",    :dired_flag_file_deletion_command)
    DIRED_MODE_MAP.define_key("u",    :dired_unmark_command)
    DIRED_MODE_MAP.define_key("U",    :dired_unmark_all_command)
    DIRED_MODE_MAP.define_key("x",    :dired_do_flagged_delete_command)
    DIRED_MODE_MAP.define_key("R",    :dired_do_rename_command)
    DIRED_MODE_MAP.define_key("C",    :dired_do_copy_command)
    DIRED_MODE_MAP.define_key("+",    :dired_create_directory_command)
    DIRED_MODE_MAP.define_key("g",    :dired_revert_command)
    DIRED_MODE_MAP.define_key("q",    :bury_buffer)

    # Deletion-flagged lines
    define_syntax :dired_flagged,    /^D .+$/
    # Symlinks
    define_syntax :dired_symlink,    /^[ D] \S+\s+\d+\s+[\d-]+ [\d:]+ .+ -> .+$/
    # Directories
    define_syntax :dired_directory,  /^[ D] d\S+\s+\d+\s+[\d-]+ [\d:]+ .+\/$/
    # Executables
    define_syntax :dired_executable, /^[ D] -[r-][w-]x.+$/

    PERM_BITS = [
      ["r", 0400], ["w", 0200], ["x", 0100],
      ["r", 0040], ["w", 0020], ["x", 0010],
      ["r", 0004], ["w", 0002], ["x", 0001]
    ]

    def self.format_permissions(stat)
      type = if stat.directory?  then "d"
             elsif stat.symlink? then "l"
             elsif stat.pipe?    then "p"
             elsif stat.socket?  then "s"
             elsif stat.chardev? then "c"
             elsif stat.blockdev? then "b"
             else "-"
             end
      type + PERM_BITS.map { |ch, mask| stat.mode & mask != 0 ? ch : "-" }.join
    end

    def self.generate_listing(dir)
      entries = []
      Dir.foreach(dir) do |name|
        next if name == "." || name == ".."
        path = File.join(dir, name)
        begin
          stat = File.lstat(path)
          perms = format_permissions(stat)
          size  = stat.size
          mtime = stat.mtime.strftime("%Y-%m-%d %H:%M")
          if stat.symlink?
            begin
              target = File.readlink(path)
            rescue SystemCallError
              target = "?"
            end
            display = "#{name} -> #{target}"
          elsif stat.directory?
            display = "#{name}/"
          else
            display = name
          end
          entries << {
            name: name,
            display: display,
            perms: perms,
            size: size,
            mtime: mtime,
            directory: stat.directory?
          }
        rescue SystemCallError => e
          entries << {
            name: name,
            display: name,
            perms: "??????????",
            size: 0,
            mtime: "????-??-?? ??:??",
            directory: false,
            error: e.message
          }
        end
      end

      entries.sort_by! { |e| [e[:directory] ? 0 : 1, e[:name].downcase] }

      lines = ["  #{dir}:\n"]
      entries.each do |e|
        line = "  #{e[:perms]}  #{e[:size].to_s.rjust(8)}  #{e[:mtime]}  #{e[:display]}\n"
        lines << line
      end
      lines.join
    end

    def initialize(buffer)
      super(buffer)
      buffer.keymap = DIRED_MODE_MAP
    end

    define_local_command(:dired_next_line, doc: "Move to next file line.") do
      @buffer.next_line
    end

    define_local_command(:dired_previous_line, doc: "Move to previous file line.") do
      line = @buffer.save_excursion {
        @buffer.beginning_of_buffer
        @buffer.current_line
      }
      if @buffer.current_line > line + 1
        @buffer.previous_line
      end
    end

    define_local_command(:dired_up_directory, doc: "Go up to parent directory.") do
      dir = @buffer[:dired_directory]
      parent = File.dirname(dir)
      dired(parent)
    end

    define_local_command(:dired_find_file, doc: "Visit file or directory at point.") do
      name = current_file_name
      return unless name
      dir = @buffer[:dired_directory]
      path = File.join(dir, name)
      if File.directory?(path)
        dired(path)
      else
        find_file(path)
      end
    end

    define_local_command(:dired_find_file_other_window,
                         doc: "Visit file at point in other window.") do
      name = current_file_name
      return unless name
      dir = @buffer[:dired_directory]
      path = File.join(dir, name)
      if Window.list.size == 1
        split_window
      end
      other_window
      if File.directory?(path)
        dired(path)
      else
        find_file(path)
      end
    end

    define_local_command(:dired_flag_file_deletion,
                         doc: "Flag file at point for deletion.") do
      set_flag("D")
      @buffer.next_line
    end

    define_local_command(:dired_unmark, doc: "Remove deletion flag from file at point.") do
      set_flag(" ")
      @buffer.next_line
    end

    define_local_command(:dired_unmark_all, doc: "Remove all deletion flags.") do
      @buffer.save_excursion do
        @buffer.beginning_of_buffer
        while !@buffer.end_of_buffer?
          set_flag(" ")
          @buffer.next_line
        end
      end
    end

    define_local_command(:dired_do_flagged_delete,
                         doc: "Delete files flagged for deletion.") do
      files = collect_flagged_files
      return if files.empty?
      list = files.map { |f| "  #{f}" }.join("\n")
      if yes_or_no?("Delete these files?")
        files.each do |name|
          next if name == "." || name == ".."
          path = File.join(@buffer[:dired_directory], name)
          begin
            if File.directory?(path) && !File.symlink?(path)
              FileUtils.rm_rf(path)
            else
              File.delete(path)
            end
          rescue SystemCallError => e
            message("Error deleting #{name}: #{e.message}")
          end
        end
        dired_revert
      end
    end

    define_local_command(:dired_do_rename, doc: "Rename/move file at point.") do
      name = current_file_name
      return unless name
      dir = @buffer[:dired_directory]
      src = File.join(dir, name)
      dest = read_file_name("Rename #{name} to: ", default: dir + "/")
      dest = File.expand_path(dest, dir)
      FileUtils.mv(src, dest)
      dired_revert
    end

    define_local_command(:dired_do_copy, doc: "Copy file at point.") do
      name = current_file_name
      return unless name
      dir = @buffer[:dired_directory]
      src = File.join(dir, name)
      dest = read_file_name("Copy #{name} to: ", default: dir + "/")
      dest = File.expand_path(dest, dir)
      FileUtils.cp_r(src, dest)
      dired_revert
    end

    define_local_command(:dired_create_directory, doc: "Create a new directory.") do
      dir = @buffer[:dired_directory]
      name = read_from_minibuffer("Create directory: ", default: dir + "/")
      name = File.expand_path(name, dir)
      FileUtils.mkdir_p(name)
      dired_revert
    end

    define_local_command(:dired_revert, doc: "Refresh directory listing.") do
      dir = @buffer[:dired_directory]
      @buffer.read_only_edit do
        @buffer.clear
        @buffer.insert(DiredMode.generate_listing(dir))
        @buffer.beginning_of_buffer
        @buffer.forward_line
      end
    end

    private

    def current_file_name
      @buffer.save_excursion do
        @buffer.beginning_of_line
        # Line format: "  perms  size  date time  display_name"
        # or:          "D perms  size  date time  display_name"
        if @buffer.looking_at?(/^[D ] (\S+)\s+\d+\s+[\d-]+\s+[\d:]+\s+(.+)$/)
          perms = @buffer.match_string(1)
          display = @buffer.match_string(2)
          # Strip symlink target: "name -> target" -> "name" (only for symlinks)
          display = display.sub(/ -> .+$/, "") if perms.start_with?("l")
          # Strip trailing slash for directories: "name/" -> "name"
          display = display.chomp("/")
          display
        end
      end
    end

    def set_flag(char)
      @buffer.read_only_edit do
        @buffer.save_excursion do
          @buffer.beginning_of_line
          if @buffer.looking_at?(/^[D ]/)
            @buffer.delete_char(1)
            @buffer.insert(char)
          end
        end
      end
    end

    def collect_flagged_files
      files = []
      @buffer.save_excursion do
        @buffer.beginning_of_buffer
        while !@buffer.end_of_buffer?
          @buffer.beginning_of_line
          if @buffer.looking_at?(/^D (\S+)\s+\d+\s+[\d-]+\s+[\d:]+\s+(.+)$/)
            perms = @buffer.match_string(1)
            display = @buffer.match_string(2)
            display = display.sub(/ -> .+$/, "") if perms.start_with?("l")
            display = display.chomp("/")
            files << display
          end
          @buffer.next_line
        end
      end
      files
    end
  end
end
