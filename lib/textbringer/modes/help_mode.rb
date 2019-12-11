module Textbringer
  class HelpMode < Mode
    define_generic_command :jump_to_link

    define_keymap :HELP_MODE_MAP
    HELP_MODE_MAP.define_key(?\C-m, :jump_to_link_command)
    HELP_MODE_MAP.define_key(?l, :help_go_back)
    HELP_MODE_MAP.define_key("\C-c\C-b", :help_go_back)
    HELP_MODE_MAP.define_key(?r, :help_go_forward)
    HELP_MODE_MAP.define_key("\C-c\C-f", :help_go_forward)
    HELP_MODE_MAP.define_key("q", :bury_buffer)

    define_syntax :link, /
      (?: ^\S*?:\d+$ ) |
      (?: \[[_a-zA-Z][_a-zA-Z0-9]*\] )
    /x

    def initialize(buffer)
      super(buffer)
      buffer.keymap = HELP_MODE_MAP
    end

    def jump_to_link
      @buffer.save_excursion do
        @buffer.skip_re_backward(/[_a-zA-Z0-9]/)
        if @buffer.char_before == ?[ &&
            @buffer.looking_at?(/([_a-zA-Z][_a-zA-Z0-9]*)\]/)
          describe_command(match_string(1))
        else
          @buffer.beginning_of_line
          if @buffer.looking_at?(/^(\S*?):(\d+)$/)
            file_name = @buffer.match_string(1)
            line_number = @buffer.match_string(2).to_i
            find_file(file_name)
            goto_line(line_number)
          end
        end
      end
    end
  end
end
