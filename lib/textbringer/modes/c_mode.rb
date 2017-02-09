# frozen_string_literal: true

module Textbringer
  CONFIG[:c_indent_level] = 4
  CONFIG[:c_indent_tabs_mode] = true

  class CMode < ProgrammingMode
    self.file_name_pattern =  /\A.*\.[ch]\z/i

    def initialize(buffer)
      super(buffer)
      @buffer[:indent_level] = CONFIG[:c_indent_level]
      @buffer[:indent_tabs_mode] = CONFIG[:c_indent_tabs_mode]
    end

    def compile(cmd = read_from_minibuffer("Compile: ",
                                           default: default_compile_command))
      shell_execute(cmd, "*Compile result*")
    end

    def symbol_pattern
      /[A-Za-z0-9\_\\]/
    end

    def default_compile_command
      "make"
    end

    private

    TOKEN_REGEXP = /\G(?:
(?<keyword>
  auto | break | case | char | const | continue | default | do | double |
  else | enum | extern | float | for | goto | if | inline | int | long |
  register | restrict | return | short | signed | sizeof | static | struct |
  switch | typedef | union | unsigned | void | volatile | while | _Bool |
  _Complex | _Imaginary
) |
(?<identifier>
  (?<identifier_nondigit>
    [_a-zA-Z] |
    (?<universal_character_name>
      \\u[0-9a-fA-F]{4} |
      \\U[0-9a-fA-F]{8} ) )
          (?: \g<identifier_nondigit> | [0-9] )*
) |
(?<constant>
  (?<floating_constant>
    (?<decimal_floating_constant>
      (?<fractional_constant>
        (?<digit_sequence> [0-9]+ )? \. \g<digit_sequence> |
        \g<digit_sequence> \. )
          (?<exponent_part> [eE] [+\-]? \g<digit_sequence> )?
          (?<floating_suffix> [flFL] )?
    ) |
    (?<hexadecimal_floating_constant>
      (?<hexadecimal_prefix> 0x | 0X )
          (?<hexadecimal_fractional_constant>
            (?<hexadecimal_digit_sequence> [0-9a-fA-F]+ )? \.
                \g<hexadecimal_digit_sequence> |
            \g<hexadecimal_digit_sequence> \. )
          (?<binary_exponent_part> [pP] [+\-]? \g<digit_sequence> )
          \g<floating_suffix>? |
      \g<hexadecimal_prefix> \g<hexadecimal_digit_sequence>
          \g<binary_exponent_part> \g<floating_suffix>?
    )
  ) |
  (?<integer_constant>
    (?<decimal_constant> [1-9][0-9]* )
    (?<integer_suffix>
      (?<unsigned_suffix> [uU] ) (?<long_suffix> [lL] )?
      \g<unsigned_suffix> (?<long_long_suffix> ll | LL )?
      \g<long_suffix> \g<unsigned_suffix>?
      \g<long_long_suffix> \g<unsigned_suffix>?
    )? |
    (?<hexadecimal_constant>
      \g<hexadecimal_prefix> \g<hexadecimal_digit_sequence> )
          \g<integer_suffix>? |
    (?<octal_constant> 0 (?<octal_digit> [0-7] )* )
        \g<integer_suffix>?
  ) |
  (?<character_constant>
    ' (?<c_char_sequence>
        (?<c_char>
          [^'\\\r\n] |
          (?<escape_sequence>
            (?<simple_escape_sequence> \\ ['"?\\abfnrtv] ) |
            (?<octal_escape_sequence>
              \\ \g<octal_digit> |
              \\ \g<octal_digit> \g<octal_digit> |
              \\ \g<octal_digit> \g<octal_digit> \g<octal_digit> ) |
            (?<hexadecimal_escape_sequence>
              \\x hexadecimal_digit_sequence ) |
            \g<universal_character_name>
          )
        )+
      ) ' |
    L' \g<c_char_sequence> '
  )
) |
(?<unknown>.)
    )/x

    def lex(s)
      
    end

    def calculate_indentation
      if @buffer.current_line == 1
        return 0
      end
      @buffer.save_excursion do
        @buffer.beginning_of_line
        bol_pos = @buffer.point
        tokens = lex(@buffer.substring(@buffer.point_min,
                                       @buffer.point))
        _, event, = tokens.last
        if event == :on_tstring_beg ||
            event == :on_heredoc_beg ||
            event == :on_tstring_content
          return nil
        end
        line, column, event, = find_nearest_beginning_token(tokens)
        if event == :on_lparen
          return column + 1
        end
        if line
          @buffer.goto_line(line)
          while !@buffer.beginning_of_buffer?
            if @buffer.save_excursion {
              @buffer.backward_char
              @buffer.skip_re_backward(/\s/)
              @buffer.char_before == ?,
            }
              @buffer.backward_line
            else
              break
            end
          end
        else
          @buffer.backward_line
        end
        @buffer.looking_at?(/[ \t]*/)
        base_indentation = @buffer.match_string(0).
          gsub(/\t/, " " * @buffer[:tab_width]).size
        @buffer.goto_char(bol_pos)
        if line.nil? ||
          @buffer.looking_at?(/[ \t]*([}\])]|(end|else|elsif|when|rescue|ensure)\b)/)
          indentation = base_indentation
        else
          indentation = base_indentation + @buffer[:indent_level]
        end
        _, last_event, last_text = tokens.reverse_each.find { |_, e, _|
          e != :on_sp && e != :on_nl && e != :on_ignored_nl
        }
        if (last_event == :on_op && last_text != "|") ||
            last_event == :on_period
          indentation += @buffer[:indent_level]
        end
        indentation
      end
    end
    
    BLOCK_END = {
      "{" => "}",
      "(" => ")",
      "[" => "]"
    }

    def find_nearest_beginning_token(tokens)
      stack = []
      (tokens.size - 1).downto(0) do |i|
        (line, column), event, text = tokens[i]
        case event
        when :on_kw
          case text
          when "class", "module", "def", "if", "unless", "case",
            "do", "for", "while", "until", "begin"
            if /\A(if|unless|while|until)\z/ =~ text
              ts = tokens[0...i].reverse_each.take_while { |(l,_),| l == line }
              t = ts.find { |_, e| e != :on_sp }
              next if t && !(t[1] == :on_op && t[2] == "=")
            end
            if stack.empty?
              return line, column, event, text
            end
            if stack.last != "end"
              raise EditorError, "#{@buffer.name}:#{line}: Unmatched #{text}"
            end
            stack.pop
          when "end"
            stack.push(text)
          end
        when :on_rbrace, :on_rparen, :on_rbracket
          stack.push(text)
        when :on_lbrace, :on_lparen, :on_lbracket, :on_tlambeg
          if stack.empty?
            return line, column, event, text
          end
          if stack.last != BLOCK_END[text]
            raise EditorError, "#{@buffer.name}:#{line}: Unmatched #{text}"
          end
          stack.pop
        end
      end
      return nil
    end
  end
end
