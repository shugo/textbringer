require "ripper"
begin
  require "prism"
rescue LoadError
end

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
      ) \b (?![!?]) | defined\? )
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

    def comment_start
      "#"
    end

    def initialize(buffer)
      super(buffer)
      @buffer[:indent_level] = CONFIG[:ruby_indent_level]
      @buffer[:indent_tabs_mode] = CONFIG[:ruby_indent_tabs_mode]
      if defined?(Prism)
        @buffer[:highlight_override] = method(:prism_highlight)
        @prism_cache_source = nil
        @prism_cache_tokens = nil
      end
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

    PRISM_TOKEN_FACES = {
      KEYWORD_ALIAS: :keyword, KEYWORD_AND: :keyword, KEYWORD_BEGIN: :keyword,
      KEYWORD_BEGIN_UPCASE: :keyword, KEYWORD_BREAK: :keyword,
      KEYWORD_CASE: :keyword, KEYWORD_CLASS: :keyword, KEYWORD_DEF: :keyword,
      KEYWORD_DEFINED: :keyword, KEYWORD_DO: :keyword,
      KEYWORD_DO_LOOP: :keyword, KEYWORD_ELSE: :keyword,
      KEYWORD_ELSIF: :keyword, KEYWORD_END: :keyword,
      KEYWORD_END_UPCASE: :keyword, KEYWORD_ENSURE: :keyword,
      KEYWORD_FALSE: :keyword, KEYWORD_FOR: :keyword, KEYWORD_IF: :keyword,
      KEYWORD_IF_MODIFIER: :keyword, KEYWORD_IN: :keyword,
      KEYWORD_MODULE: :keyword, KEYWORD_NEXT: :keyword, KEYWORD_NIL: :keyword,
      KEYWORD_NOT: :keyword, KEYWORD_OR: :keyword, KEYWORD_REDO: :keyword,
      KEYWORD_RESCUE: :keyword, KEYWORD_RESCUE_MODIFIER: :keyword,
      KEYWORD_RETRY: :keyword, KEYWORD_RETURN: :keyword,
      KEYWORD_SELF: :keyword, KEYWORD_SUPER: :keyword, KEYWORD_THEN: :keyword,
      KEYWORD_TRUE: :keyword, KEYWORD_UNDEF: :keyword,
      KEYWORD_UNLESS: :keyword, KEYWORD_UNLESS_MODIFIER: :keyword,
      KEYWORD_UNTIL: :keyword, KEYWORD_UNTIL_MODIFIER: :keyword,
      KEYWORD_WHEN: :keyword, KEYWORD_WHILE: :keyword,
      KEYWORD_WHILE_MODIFIER: :keyword, KEYWORD_YIELD: :keyword,

      COMMENT: :comment, EMBDOC_BEGIN: :comment, EMBDOC_LINE: :comment,
      EMBDOC_END: :comment,

      STRING_BEGIN: :string, STRING_CONTENT: :string, STRING_END: :string,
      SYMBOL_BEGIN: :string, REGEXP_BEGIN: :string, REGEXP_END: :string,
      HEREDOC_START: :string, HEREDOC_END: :string,
      INTEGER: :string, FLOAT: :string,
      INTEGER_RATIONAL: :string, FLOAT_RATIONAL: :string,
      INTEGER_IMAGINARY: :string, FLOAT_IMAGINARY: :string,
      INTEGER_RATIONAL_IMAGINARY: :string, FLOAT_RATIONAL_IMAGINARY: :string,
      LABEL: :string,
    }.freeze

    INDENT_BEG_RE = /^([ \t]*)(class|module|def|if|unless|case|while|until|for|begin)\b/

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

    def lex(source)
      line_count = source.count("\n")
      s = source
      lineno = 1
      tokens = []
      loop do
        lexer = Ripper::Lexer.new(s, "-", lineno)
        tokens.concat(lexer.lex)
        last_line = tokens.dig(-1, 0, 0)
        return tokens if last_line.nil? || last_line >= line_count
        s = source.sub(/(.*\n?){#{last_line}}/, "")
        return tokens if last_line + 1 <= lineno
        lineno = last_line + 1
      end
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
        tokens = lex(@buffer.substring(start_pos, bol_pos))
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
        i, extra_end_count = find_nearest_beginning_token(tokens)
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
          indentation =
            base_indentation - extra_end_count * @buffer[:indent_level]
        else
          indentation = base_indentation + @buffer[:indent_level]
        end
        if @buffer.looking_at?(/[ \t]*([}\])]|(end|else|elsif|when|in|rescue|ensure)\b)/)
          indentation -= @buffer[:indent_level]
        end
        _, last_event, last_text = tokens.reverse_each.find { |_, e, _|
          e != :on_sp && e != :on_nl && e != :on_ignored_nl
        }
        if start_with_period ||
            (last_event == :on_op && last_text != "|") ||
            (last_event == :on_kw && /\A(and|or)\z/.match?(last_text)) ||
            last_event == :on_period ||
            (last_event == :on_comma && event != :on_lbrace &&
             event != :on_lparen && event != :on_lbracket) ||
            last_event == :on_label
          indentation += @buffer[:indent_level]
        end
        indentation
      end
    end

    BLOCK_END = {
      '#{' => "}",
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
            if /\A(if|unless|while|until)\z/.match?(text) &&
                modifier?(tokens, i)
              next
            end
            if text == "def" && endless_method_def?(tokens, i)
              next
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
        when :on_rbrace, :on_rparen, :on_rbracket, :on_embexpr_end
          stack.push(text)
        when :on_lbrace, :on_lparen, :on_lbracket, :on_tlambeg, :on_embexpr_beg
          if stack.empty?
            return i
          end
          if stack.last != BLOCK_END[text]
            raise EditorError, "#{@buffer.name}:#{line}: Unmatched #{text}"
          end
          stack.pop
        end
      end
      return nil, stack.grep_v(/[)\]]/).size
    end

    def modifier?(tokens, i)
      (line,), = tokens[i]
      ts = tokens[0...i].reverse_each.take_while { |(l,_),| l == line }
      t = ts.find { |_, e| e != :on_sp }
      t && !(t[1] == :on_op && t[2] == "=")
    end

    def endless_method_def?(tokens, i)
      ts = tokens.drop(i + 1)
      ts.shift while ts[0][1] == :on_sp
      _, event = ts.shift
      return false if event != :on_ident
      ts.shift while ts[0][1] == :on_sp
      if ts[0][1] == :on_lparen
        ts.shift
        count = 1
        while count > 0
          _, event = ts.shift
          return false if event.nil?
          case event
          when :on_lparen
            count +=1
          when :on_rparen
            count -=1
          end
        end
        ts.shift while ts[0][1] == :on_sp
      end
      ts[0][1] == :on_op && ts[0][2] == "="
    rescue NoMethodError # no token
      return false
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

    def prism_highlight
      highlight_on = {}
      highlight_off = {}
      return [highlight_on, highlight_off] if !Window.has_colors? ||
        !CONFIG[:syntax_highlight] || @buffer.binary?
      if @buffer.bytesize < CONFIG[:highlight_buffer_size_limit]
        base_pos = @buffer.point_min
        source = @buffer.to_s
      else
        base_pos = @buffer.point
        window = Window.current
        len = window.columns * (window.lines - 1) / 2 * 3
        source = @buffer.substring(@buffer.point,
                                   @buffer.point + len).scrub("")
      end
      return [highlight_on, highlight_off] if !source.valid_encoding?
      if source == @prism_cache_source
        tokens = @prism_cache_tokens
      else
        tokens = Prism.lex(source).value
        @prism_cache_source = source
        @prism_cache_tokens = tokens
      end
      in_symbol = false
      tokens.each do |token_info|
        token = token_info[0]
        face_name = PRISM_TOKEN_FACES[token.type]
        if face_name.nil? && in_symbol
          face_name = :string
        end
        in_symbol = token.type == :SYMBOL_BEGIN
        next unless face_name
        face = Face[face_name]
        next unless face
        offset = token.location.start_offset
        length = token.location.length
        pos = base_pos + offset
        if pos < @buffer.point && @buffer.point < pos + length
          pos = @buffer.point
        end
        highlight_on[pos] = face
        highlight_off[pos + length] = true
      end
      [highlight_on, highlight_off]
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
