# frozen_string_literal: true

module Textbringer
  class BacktraceMode < Mode
    define_generic_command :jump_to_source_location

    BACKTRACE_MODE_MAP = Keymap.new
    BACKTRACE_MODE_MAP.define_key("\n", :jump_to_source_location_command)

    def initialize(buffer)
      super(buffer)
      buffer.keymap = BACKTRACE_MODE_MAP
    end

    def jump_to_source_location
      file_name, line_number = get_source_location
      if file_name
        find_file(file_name)
        goto_line(line_number)
      end
    end

    private

    def get_source_location
      @buffer.save_excursion do
        @buffer.beginning_of_line
        if @buffer.looking_at?(/^(\S*?):(\d+):/)
          file_name = @buffer.match_string(1)
          line_number = @buffer.match_string(2).to_i
          [file_name, line_number]
        else
          nil
        end
      end
    end
  end
end
