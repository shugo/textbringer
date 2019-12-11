module Textbringer
  class BacktraceMode < Mode
    define_generic_command :jump_to_source_location

    define_keymap :BACKTRACE_MODE_MAP
    BACKTRACE_MODE_MAP.define_key("\C-m", :jump_to_source_location_command)

    define_syntax :link, /^\S*?:\d+:(?:\d+:)?/

    def initialize(buffer)
      super(buffer)
      buffer.keymap = BACKTRACE_MODE_MAP
    end

    def jump_to_source_location
      file_name, line_number, column_number = get_source_location
      if file_name
        find_file(file_name)
        goto_line(line_number)
        forward_char(column_number - 1)
      end
    end

    private

    def get_source_location
      @buffer.save_excursion do
        @buffer.beginning_of_line
        if @buffer.looking_at?(/^(\S*?):(\d+):(?:(\d+):)?/)
          file_name = @buffer.match_string(1)
          line_number = @buffer.match_string(2).to_i
          column_number = (@buffer.match_string(3) || 1).to_i
          [file_name, line_number, column_number]
        else
          nil
        end
      end
    end
  end
end
