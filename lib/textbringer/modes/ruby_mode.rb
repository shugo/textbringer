# frozen_string_literal: true

require "ripper"

module Textbringer
  CONFIG[:ruby_indent_level] = 2
  CONFIG[:ruby_indent_tabs_mode] = false

  class RubyMode < ProgrammingMode
    self.file_name_pattern =
      /\A(?:.*\.(?:rb|ru|rake|thor|jbuilder|gemspec|podspec)|
            (?:Gem|Rake|Cap|Thor|Vagrant|Guard|Pod)file)\z/ix
    self.interpreter_name_pattern = /ruby/i

    define_syntax :comment, /
      (?: \#.*(?:\\\n.*)*(?:\z|(?<!\\)\n) ) |
      (?: ^=begin (?:.|\n)* (?> ^=end \b ) )
    /x

    define_syntax :keyword, /
      (?<![$@.]) \b (?: (?:
        class | module | def | undef | begin | rescue | ensure | end |
        if | unless | then | elsif | else | case | when | while | until |
        for | break | next | redo | retry | in | do | return | yield |
        super | self | nil | true | false | and | or | not | alias
      ) \b | defined\? )
    /x

    define_syntax :string, /
      (?: (?<! [a-zA-Z] ) \?
              (:?
                [^\\\s] |
                \\ [0-7]{1,3} |
                \\x [0-9a-fA-F]{2} |
                \\u [0-9a-fA-F]{4} |
                \\u \{ [0-9a-fA-F]+ \} |
                \\C - . |
                \\M - . |
                \\ .
              )
      ) |
      (?: %[qQrwWsiIx]?\{ (?: [^\\}] | \\ .  )* \} ) |
      (?: %[qQrwWsiIx]?\( (?: [^\\)] | \\ .  )* \) ) |
      (?: %[qQrwWsiIx]?\[ (?: [^\\\]] | \\ .  )* \] ) |
      (?: %[qQrwWsiIx]?< (?: [^\\>] | \\ .  )* > ) |
      (?:
         %[qQrwWsiIx]?
             (?<string_delimiter>[^{(\[<a-zA-Z0-9\s\u{0100}-\u{10ffff}])
             (?: (?! \k<string_delimiter> ) [^\\] | \\ .  )*
             \k<string_delimiter>
      ) |
      (?:
        (?<! \$ )
            " (?: [^\\"] | \\ .  )* "
      ) |
      (?:
        (?<! \$ )
            ' (?: [^\\'] | \\ .  )* '
      ) |
      (?:
         (?<! [$.] | def | def \s )
             ` (?: [^\\`] | \\ .  )* `
      ) |
      (?:
        (?<=
          ^ |
          \b and | \b or | \b while | \b until | \b unless | \b if |
          \b elsif | \b when | \b not | \b then | \b else |
          [;~=!|&(,\[<>?:*+-]
        ) \s*
        \/ (?: [^\\\/] | \\ .  )* \/[iomxneus]*
      ) |
      (?:
        (?<! class | class \s | [\]})"'.] | :: | \w )
            <<[\-~]?(?<heredoc_quote>['"`]?)
            (?<heredoc_terminator>
              (?> [_a-zA-Z\u{0100}-\u{10ffff}]
                  [_a-zA-Z0-9\u{0100}-\u{10ffff}]* )
            )
            \k<heredoc_quote>
            (?> (?:.|\n)*? ^ [\ \t]* \k<heredoc_terminator> $ )
      ) |
      (?:
        (?<! : ) :
            [_a-zA-Z\u{0100}-\u{10ffff}]
            [_a-zA-Z0-9\u{0100}-\u{10ffff}]*
      )
    /x

    def initialize(buffer)
      super(buffer)
      @buffer[:indent_level] = CONFIG[:ruby_indent_level]
      @buffer[:indent_tabs_mode] = CONFIG[:ruby_indent_tabs_mode]
    end

    def forward_definition(n = number_prefix_arg || 1)
      tokens = Ripper.lex(@buffer.to_s)
      @buffer.forward_line
      n.times do |i|
        tokens = tokens.drop_while { |(l, _), e, t|
          l < @buffer.current_line ||
            e != :on_kw || /\A(?:class|module|def)\z/ !~ t
        }
        (line,), = tokens.first
        if line.nil?
          @buffer.end_of_buffer
          break
        end
        @buffer.goto_line(line)
        tokens = tokens.drop(1)
      end
      while /\s/ =~ @buffer.char_after
        @buffer.forward_char
      end
    end

    def backward_definition(n = number_prefix_arg || 1)
      tokens = Ripper.lex(@buffer.to_s).reverse
      @buffer.beginning_of_line
      n.times do |i|
        tokens = tokens.drop_while { |(l, _), e, t|
          l >= @buffer.current_line ||
            e != :on_kw || /\A(?:class|module|def)\z/ !~ t
        }
        (line,), = tokens.first
        if line.nil?
          @buffer.beginning_of_buffer
          break
        end
        @buffer.goto_line(line)
        tokens = tokens.drop(1)
      end
      while /\s/ =~ @buffer.char_after
        @buffer.forward_char
      end
    end

    def compile(cmd = read_from_minibuffer("Compile: ",
                                           default: default_compile_command))
      shell_execute(cmd, buffer_name: "*Ruby compile result*",
                    mode: BacktraceMode)
    end

    def symbol_pattern
      /[\p{Letter}\p{Number}_$@!?]/
    end

    def default_compile_command
      @buffer[:ruby_compile_command] ||
        if File.exist?("Rakefile")
          prefix = File.exist?("Gemfile") ? "bundle exec " : ""
          prefix + "rake"
        elsif @buffer.file_name
          ruby_install_name + " " + @buffer.file_name
        else
          nil
        end
    end

    def toggle_test
      case @buffer.file_name
      when %r'(.*)/test/(.*/)?test_(.*?)\.rb\z'
        path = find_test_target_path($1, $2, $3)
        find_file(path)
      when %r'(.*)/spec/(.*/)?(.*?)_spec\.rb\z'
        path = find_test_target_path($1, $2, $3)
        find_file(path)
      when %r'(.*)/(?:lib|app)/(.*/)?(.*?)\.rb\z'
        path = find_test_path($1, $2, $3)
        find_file(path)
      else
        raise EditorError, "Unknown file type"
      end
    end

    private

    INDENT_BEG_RE = /^([ \t]*)((class|module|def|if|unless|case|while|until|for|begin|end)\b|\})/

    def space_width(s)
      s.gsub(/\t/, " " * @buffer[:tab_width]).size
    end

    def beginning_of_indentation
      loop do
        @buffer.re_search_backward(INDENT_BEG_RE)
        space = @buffer.match_string(1)
        s = @buffer.substring(@buffer.point_min, @buffer.point)
        if PartialLiteralAnalyzer.in_literal?(s)
          next
        end
        return space_width(space)
      end
    rescue SearchError
      @buffer.beginning_of_buffer
      0
    end

    def calculate_indentation
      if @buffer.current_line == 1
        return 0
      end
      @buffer.save_excursion do
        @buffer.beginning_of_line
        start_with_period = @buffer.looking_at?(/[ \t]*\./)
        bol_pos = @buffer.point
        base_indentation = beginning_of_indentation
        start_pos = @buffer.point
        start_line = @buffer.current_line
        tokens = Ripper.lex(@buffer.substring(start_pos, bol_pos))
        _, event, text = tokens.last
        if event == :on_nl
          _, event, text = tokens[-2]
        end
        if event == :on_tstring_beg ||
            event == :on_heredoc_beg ||
            event == :on_regexp_beg ||
            (event == :on_regexp_end && text.size > 1) ||
            event == :on_tstring_content
          return nil
        end
        i = find_nearest_beginning_token(tokens)
        (line, column), event, = i ? tokens[i] : nil
        if event == :on_lparen && tokens.dig(i + 1, 1) != :on_ignored_nl
          return column + 1
        end
        if line
          @buffer.goto_line(start_line - 1 + line)
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
          @buffer.looking_at?(/[ \t]*/)
          base_indentation = space_width(@buffer.match_string(0))
        end
        @buffer.goto_char(bol_pos)
        if line.nil?
          indentation = base_indentation
        else
          indentation = base_indentation + @buffer[:indent_level]
        end
        if @buffer.looking_at?(/[ \t]*([}\])]|(end|else|elsif|when|rescue|ensure)\b)/)
          indentation -= @buffer[:indent_level]
        end
        _, last_event, last_text = tokens.reverse_each.find { |_, e, _|
          e != :on_sp && e != :on_nl && e != :on_ignored_nl
        }
        if start_with_period ||
            (last_event == :on_op && last_text != "|") ||
            last_event == :on_period ||
            (last_event == :on_comma && event != :on_lbrace &&
             event != :on_lparen && event != :on_lbracket)
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
        (line, ), event, text = tokens[i]
        case event
        when :on_kw
          _, prev_event, _ = tokens[i - 1]
          next if prev_event == :on_symbeg
          case text
          when "class", "module", "def", "if", "unless", "case",
            "do", "for", "while", "until", "begin"
            if /\A(if|unless|while|until)\z/.match?(text)
              ts = tokens[0...i].reverse_each.take_while { |(l,_),| l == line }
              t = ts.find { |_, e| e != :on_sp }
              next if t && !(t[1] == :on_op && t[2] == "=")
            end
            if stack.empty?
              return i
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
            return i
          end
          if stack.last != BLOCK_END[text]
            raise EditorError, "#{@buffer.name}:#{line}: Unmatched #{text}"
          end
          stack.pop
        end
      end
      return nil
    end

    def find_test_target_path(base, namespace, name)
      patterns = []
      if namespace
        patterns.push("#{base}/{lib,app}/**/#{namespace}#{name}.rb")
      end
      patterns.push("#{base}/{lib,app}/**/#{name}.rb")
      find_first_path(patterns) or raise EditorError, "Test target not found"
    end

    def find_test_path(base, namespace, name)
      patterns = []
      if namespace
        patterns.push("#{base}/test/**/#{namespace}test_#{name}.rb")
        patterns.push("#{base}/spec/**/#{namespace}#{name}_spec.rb")
      end
      patterns.push("#{base}/test/**/test_#{name}.rb")
      patterns.push("#{base}/spec/**/#{name}_spec.rb")
      find_first_path(patterns) or raise EditorError, "Test not found"
    end

    def find_first_path(patterns)
      patterns.each do |pattern|
        paths = Dir.glob(pattern)
        return paths.first if !paths.empty?
      end
      nil
    end

    class PartialLiteralAnalyzer < Ripper
      def self.in_literal?(src)
        new(src).in_literal?
      end

      def in_literal?
        @literal_level = 0
        parse
        @literal_level > 0
      end

      private

      %w(embdoc heredoc tstring regexp
      symbols qsymbols words qwords).each do |name|
        define_method("on_#{name}_beg") do |token|
          @literal_level += 1
        end
      end

      %w(embdoc heredoc tstring regexp).each do |name|
        define_method("on_#{name}_end") do |token|
          @literal_level -= 1
        end
      end
    end
  end
end
