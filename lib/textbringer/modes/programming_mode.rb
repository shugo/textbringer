module Textbringer
  class ProgrammingMode < FundamentalMode
    # abstract mode
    undefine_command(:programming_mode)

    define_generic_command :indent_line
    define_generic_command :reindent_then_newline_and_indent
    define_generic_command :indent_region
    define_generic_command :forward_definition
    define_generic_command :backward_definition
    define_generic_command :compile
    define_generic_command :toggle_test

    define_keymap :PROGRAMMING_MODE_MAP
    PROGRAMMING_MODE_MAP.define_key("\t", :indent_line_command)
    PROGRAMMING_MODE_MAP.define_key("\C-m",
                                    :reindent_then_newline_and_indent_command)
    PROGRAMMING_MODE_MAP.define_key("\M-\C-\\", :indent_region_command)
    PROGRAMMING_MODE_MAP.define_key("\C-c\C-n", :forward_definition_command)
    PROGRAMMING_MODE_MAP.define_key("\C-c\C-p", :backward_definition_command)
    PROGRAMMING_MODE_MAP.define_key("\C-c\C-c", :compile_command)
    PROGRAMMING_MODE_MAP.define_key("\C-c\C-t", :toggle_test_command)

    def initialize(buffer)
      super(buffer)
      buffer.keymap = PROGRAMMING_MODE_MAP
    end

    # Return true if modified.
    def indent_line
      result = false
      level = calculate_indentation
      return result if level.nil? || level < 0
      @buffer.save_excursion do
        @buffer.beginning_of_line
        @buffer.composite_edit do
          if @buffer.looking_at?(/[ \t]+/)
            s = @buffer.match_string(0)
            break if /\t/ !~ s && s.size == level
            @buffer.delete_region(@buffer.match_beginning(0),
                                  @buffer.match_end(0))
          else
            break if level == 0
          end
          @buffer.indent_to(level)
        end
        result = true
      end
      pos = @buffer.point
      @buffer.beginning_of_line
      @buffer.forward_char while /[ \t]/ =~ @buffer.char_after
      if @buffer.point < pos
        @buffer.goto_char(pos)
      end
      result
    end

    def reindent_then_newline_and_indent
      @buffer.composite_edit do
        indent_line
        @buffer.save_excursion do
          pos = @buffer.point
          @buffer.beginning_of_line
          if /\A[ \t]+\z/.match?(@buffer.substring(@buffer.point, pos))
            @buffer.delete_region(@buffer.point, pos)
          end
        end
        @buffer.insert("\n")
        indent_line
      end
    end

    def indent_region(s = @buffer.mark, e = @buffer.point)
      s, e = Buffer.region_boundaries(s, e)
      end_mark = @buffer.new_mark(e)
      begin
        @buffer.save_excursion do
          @buffer.goto_char(s)
          until @buffer.end_of_buffer? || @buffer.point_after_mark?(end_mark)
            indent_line
            @buffer.forward_line
          end
        end
      ensure
        end_mark.delete
      end
    end

    private

    def calculate_indentation
      raise EditorError, "indent_line is not defined in the current mode"
    end
  end
end
