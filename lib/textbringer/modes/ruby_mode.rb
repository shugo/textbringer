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
        has_space = @buffer.looking_at?(/ +/)
        if has_space
          break if @buffer.match_string(0).size == level
          @buffer.delete_region(@buffer.match_beginning(0),
                                @buffer.match_end(0))
        end
        @buffer.insert(" " * level)
        if has_space
          @buffer.merge_undo(2)
        end
      end
      if @buffer.current_column - 1 < level
        @buffer.forward_char(level - (@buffer.current_column - 1))
      end
    end

    private

    def calculate_indentation
      if @buffer.current_line == 1
        return 0
      end
      @buffer.save_excursion do
        @buffer.beginning_of_line
        bol_pos = @buffer.point
        tokens = Ripper.lex(@buffer.substring(buffer.point_min, buffer.point))
        line, column, event, text = find_nearest_beginning_token(tokens)
        if line
          @buffer.goto_line(line)
        else
          @buffer.previous_line
        end
        @buffer.looking_at?(/ */)
        base_indentation = @buffer.match_string(0).size
        @buffer.goto_char(bol_pos)
        if line.nil? || @buffer.looking_at?(/ *([}\])]|(end|else|when)\b)/)
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
      (tokens.size - 1).downto(0) do |i|
        (line, column), event, text = tokens[i]
        case event
        when :on_kw
          case text
          when "class", "module", "def", "for", "if", "unless", "case", "do"
            if /\A(if|unless|while)\z/ =~ text
              ts = tokens[0...i].reverse_each.take_while { |(l,_),| l == line }
              t = ts.find { |_, e| e != :on_sp }
              next if t && !(t[1] == :on_op && t[2] == "=")
            end
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
