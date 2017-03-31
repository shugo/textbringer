# frozen_string_literal: true

module Textbringer
  CONFIG[:c_indent_level] = 4
  CONFIG[:c_indent_tabs_mode] = true
  CONFIG[:c_continued_statement_offset] = 4
  CONFIG[:c_case_label_offset] = -4
  CONFIG[:c_label_offset] = -2

  class CMode < ProgrammingMode
    self.file_name_pattern =  /\A.*\.[ch]\z/i

    KEYWORDS = %w(
      auto break case char const continue default double do
      else enum extern float for goto if inline int long
      register restrict return short signed sizeof static struct
      switch typedef union unsigned void volatile while _Bool
      _Complex _Imaginary
    )

    define_syntax :comment, /
      (?: \/\* (?> (?:.|\n)*? \*\/ ) ) |
      (?: \/\/ .*(?:\\\n.*)*(?:\z|(?<!\\)\n) )
    /x

    define_syntax :preprocessing_directive, /
      ^ [\ \t]* (?: \# | %: ) [\ \t]* [_a-zA-Z][_a-zA-Z0-9]*
    /x

    define_syntax :keyword, /
      \b (?: #{KEYWORDS.join("|")} ) \b
    /x

    define_syntax :string, /
      (?: " (?: [^\\"] | \\ (?:.|\n)  )* " ) |
      (?: ' (?: [^\\'] | \\ (?:.|\n)  )* ' )
    /x
    
    def initialize(buffer)
      super(buffer)
      @buffer[:indent_level] = CONFIG[:c_indent_level]
      @buffer[:indent_tabs_mode] = CONFIG[:c_indent_tabs_mode]
    end

    def compile(cmd = read_from_minibuffer("Compile: ",
                                           default: default_compile_command))
      shell_execute(cmd, buffer_name: "*Compile result*",
                    mode: BacktraceMode)
    end

    def symbol_pattern
      /[A-Za-z0-9\_\\]/
    end

    def default_compile_command
      "make"
    end

    TOKEN_NAMES = [
      :preprocessing_directive,
      :comment,
      :keyword,
      :identifier,
      :constant,
      :string_literal,
      :punctuator,
      :space,
      :partial_comment,
      :unknown
    ]
    
    TOKEN_REGEXP = /\G(?:
(?<preprocessing_directive>
  ^[ \t\f\v]*(?:\#|%:).*(?:\\\n.*)*[^\\]\n
) |
(?<comment>
  (?<multiline_comment> \/\* (?> (?:.|\n)*? \*\/ ) ) |
  (?<singleline_comment> \/\/ .*(?:\\\n.*)*(?<!\\)\n )
) |
(?<partial_comment>
  (?<partial_multiline_comment> \/\* (?:.|\n)* ) |
  (?<partial_singleline_comment> \/\/ .*? \\\n (?:.|\n)* )
) |
(?<keyword>
  (?: #{KEYWORDS.join("|")} ) \b
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
            (?<octal_escape_sequence> \\ \g<octal_digit>{1,3} ) |
            (?<hexadecimal_escape_sequence>
              \\x \g<hexadecimal_digit_sequence> ) |
            (?<universal_character_name>
              \\u[0-9a-fA-F]{4} |
              \\U[0-9a-fA-F]{8} )
          )
        )+
      ) ' |
    L' \g<c_char_sequence> '
  )
) |
(?<string_literal>
  " (?<s_char_sequence>
      (?<s_char> [^"\\\r\n] | \g<escape_sequence> )+ ) " |
  L" \g<s_char_sequence>? "
) |
(?<identifier>
  (?<identifier_nondigit>
    [_a-zA-Z] |
    \g<universal_character_name> )
        (?: \g<identifier_nondigit> | [0-9] )*
) |
(?<punctuator>
  \[   |   \]   |   \(   |   \)   |   \{   |   \}   |
  \.\.\.   |   \.   |
  \+\+   |   \+=   |   \+   |
  ->   |   --   |   -=   |   -   |
  \*=   |   \*   |
  \/=   |   \/   |
  &&   |   &=   |   &   |
  \|\|   |   \|=   |   \|   |
  !=   |   !   |
  ~   |
  ==   |   =   |
  \^=   |   \^   |
  <:   |   <%   |   <<=   |   <<   |   <=   |   <   |
  >>=   |   >>   |   >=   |   >   |
  \?   |   ;   |
  :>   |   :   |
  ,   |
  \#\#   |   \#   |
  %>   |   %:%:   |   %:   |   %=   |   %
) |
(?<space>
  \s+
) |
(?<unknown>.)
    )/x

    def lex(s)
      tokens = []
      pos = 0
      line = 1
      column = 0
      while pos < s.size && s.index(TOKEN_REGEXP, pos)
        text = $&
        token_name = TOKEN_NAMES.find { |name| $~[name] }
        if text.empty?
          raise EditorError, "Empty token: (#{line},#{column}) #{$~.inspect}"
        end
        tokens.push([[line, column], token_name, text])
        lf_count = text.count("\n")
        if lf_count > 0
          line += lf_count
          column = text.slice(/[^\n]*\z/).size
        else
          column += text.size
        end
        pos += text.size
      end
      tokens
    end

    private

    def calculate_indentation
      if @buffer.current_line == 1
        return 0
      end
      @buffer.save_excursion do
        @buffer.beginning_of_line
        if @buffer.looking_at?(/[ \t]*(?:#|%:)/)
          return 0
        end
        bol_pos = @buffer.point
        s = @buffer.substring(@buffer.point_min, @buffer.point).b
        tokens = lex(s)
        _, event, = tokens.last
        if event == :partial_comment
          return nil
        end
        line, column, event, text = find_nearest_beginning_token(tokens)
        if event == :punctuator && text == "("
          return column + 1
        end
        if line
          @buffer.goto_line(line)
        else
          (ln, _), ev = tokens.reverse_each.drop_while { |(l, _), e, t|
            l >= @buffer.current_line - 1 || e == :space
          }.first
          if ev == :comment
            @buffer.goto_line(ln)
          else
            @buffer.backward_line
          end
        end
        @buffer.looking_at?(/[ \t]*/)
        base_indentation = @buffer.match_string(0).
          gsub(/\t/, " " * @buffer[:tab_width]).size
        @buffer.goto_char(bol_pos)
        if line.nil? ||
            @buffer.looking_at?(/[ \t]*([}\])]|:>|%>)/)
          indentation = base_indentation
        else
          indentation = base_indentation + @buffer[:indent_level]
        end
        if @buffer.looking_at?(/[ \t]*(?:case.*|default):/)
          indentation += @buffer[:c_case_label_offset]
        elsif @buffer.looking_at?(/[ \t]*[_a-zA-Z0-9\\]+:/)
          indentation += @buffer[:c_label_offset]
        end
        indent_continued_statement(indentation, tokens, line)
      end
    end

    def indent_continued_statement(indentation, tokens ,line)
      if line && !@buffer.looking_at?(/[ \t]*\{/)
        _, last_event, last_text =
          tokens.reverse_each.drop_while { |(l, _), e, t|
            l == @buffer.current_line || e == :space || e == :comment
          }.first
        if last_event != :preprocessing_directive &&
            /[:;{}]/ !~ last_text
          indentation + @buffer[:c_continued_statement_offset]
        else
          indentation
        end
      else
        indentation
      end
    end

    CANONICAL_PUNCTUATORS = Hash.new { |h, k| k }
    CANONICAL_PUNCTUATORS["<:"] = "["
    CANONICAL_PUNCTUATORS[":>"] = "]"
    CANONICAL_PUNCTUATORS["<%"] = "{"
    CANONICAL_PUNCTUATORS["%>"] = "}"
    BLOCK_END = {
      "{" => "}",
      "(" => ")",
      "[" => "]"
    }
    BLOCK_BEG = BLOCK_END.invert

    def find_nearest_beginning_token(tokens)
      stack = []
      (tokens.size - 1).downto(0) do |i|
        (line, column), event, raw_text = tokens[i]
        text = CANONICAL_PUNCTUATORS[raw_text]
        case event
        when :punctuator
          if BLOCK_BEG.key?(text)
            stack.push(text)
          elsif BLOCK_END.key?(text)
            if stack.empty?
              return line, column, event, text
            end
            if stack.last != BLOCK_END[text]
              raise EditorError, "#{@buffer.name}:#{line}: Unmatched #{text}"
            end
            stack.pop
          end
        end
      end
      return nil
    end
  end
end
