# frozen_string_literal: true

require "ripper"

module Textbringer
  class RubyMode < ProgrammingMode
    def initialize(buffer)
      super(buffer)
      @indent_level = 2
    end

    def indent_line
      level = calculate_indentation
      @buffer.save_excursion do
        @buffer.beginning_of_line
        if @buffer.looking_at?(/ +/)
          @buffer.delete_region(match_beginning(0), match_end(0))
        end
        @buffer.insert(" " * level)
      end
    end

    private

    def calculate_indentation
      @buffer.save_excursion do
        beginning_of_line
        bol_pos = @buffer.point
        tokens = Ripper.lex(@buffer.substring(buffer.point_min, buffer.point))
        line, column, event, text = find_nearest_beginning_token(tokens)
        @buffer.goto_line(line)
        @buffer.looking_at?(/ */)
        base_indentation = match_string(0).size
        goto_char(bol_pos)
        if @buffer.looking_at?(/ *(end|[}\])])/)
          base_indentation
        else
          base_indentation + @indent_level
        end
      end
    end

    def find_nearest_beginning_token(tokens)
      end_count = 0
      rbrace_count = 0
      rparen_count = 0
      rbracket_count = 0
      tokens.reverse_each do |(line, column), event, text|
        case event
        when :on_kw
          case text
          when "class", "module", "def", "if", "unless", "case", "do"
            if end_count == 0
              return line, column, event, text
            end
            end_count -= 1
          when "end"
            end_count += 1
          end
        when :on_rbrace
          rbrace_count += 1
        when :on_lbrace
          if rbrace_count == 0
            return line, column, event, text
          end
          rbrace_count -= 1
        when :on_rparen
          rparen_count += 1
        when :on_lparen
          if rparen_count == 0
            return line, column, event, text
          end
          rparen_count -= 1
        when :on_rbracket
          rbracket_count += 1
        when :on_lbracket
          if rbracket_count == 0
            return line, column, event, text
          end
          rbracket_count -= 1
        end
      end
      return nil
    end
  end
end
