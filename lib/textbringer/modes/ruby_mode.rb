require "set"
require "prism"

module Textbringer
  CONFIG[:ruby_indent_level] = 2
  CONFIG[:ruby_indent_tabs_mode] = false

  class RubyMode < ProgrammingMode
    self.file_name_pattern =
      /\A(?:.*\.(?:rb|ru|rake|thor|jbuilder|gemspec|podspec)|
            (?:Gem|Rake|Cap|Thor|Vagrant|Guard|Pod)file)\z/ix
    self.interpreter_name_pattern = /ruby/i

    def comment_start
      "#"
    end

    def initialize(buffer)
      super(buffer)
      @buffer[:indent_level] = CONFIG[:ruby_indent_level]
      @buffer[:indent_tabs_mode] = CONFIG[:ruby_indent_tabs_mode]
      @prism_version = nil
      @prism_tokens = nil
      @literal_levels = nil
      @literal_levels_version = nil
    end

    def forward_definition(n = number_prefix_arg || 1)
      ensure_prism_tokens
      tokens = @prism_tokens.filter_map { |token, _state|
        type = token.type
        next if type == :EOF
        [token.location.start_line, type]
      }
      @buffer.forward_line
      n.times do |i|
        tokens = tokens.drop_while { |l, type|
          l < @buffer.current_line ||
            !DEFINITION_KEYWORDS.include?(type)
        }
        line, = tokens.first
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
      ensure_prism_tokens
      tokens = @prism_tokens.filter_map { |token, _state|
        type = token.type
        next if type == :EOF
        [token.location.start_line, type]
      }.reverse
      @buffer.beginning_of_line
      n.times do |i|
        tokens = tokens.drop_while { |l, type|
          l >= @buffer.current_line ||
            !DEFINITION_KEYWORDS.include?(type)
        }
        line, = tokens.first
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

    def highlight(ctx)
      ensure_prism_tokens
      return unless @prism_tokens
      base_pos = ctx.buffer.point_min
      in_symbol = false
      after_def = false
      @prism_tokens.each do |token_info|
        token = token_info[0]
        type = token.type
        face_name = PRISM_TOKEN_FACES[type]
        if in_symbol
          face_name = :string if face_name.nil? || face_name == :constant ||
            face_name == :operator
        elsif after_def
          face_name = :function_name if type == :IDENTIFIER ||
            type == :CONSTANT || type == :METHOD_NAME ||
            PRISM_TOKEN_FACES[type] == :operator
        end
        in_symbol = type == :SYMBOL_BEGIN
        after_def = type == :KEYWORD_DEF ||
          (after_def && (type == :KEYWORD_SELF || type == :DOT ||
                         type == :NEWLINE || type == :IGNORED_NEWLINE ||
                         type == :COMMENT))
        next unless face_name
        face = Face[face_name]
        next unless face
        offset = token.location.start_offset
        length = token.location.length
        pos = base_pos + offset
        ctx.highlight(pos, pos + length, face)
      end
    end

    private

    PRISM_TOKEN_FACES = {
      # Keywords
      KEYWORD_ALIAS: :keyword, KEYWORD_AND: :keyword, KEYWORD_BEGIN: :keyword,
      KEYWORD_BEGIN_UPCASE: :keyword, KEYWORD_BREAK: :keyword,
      KEYWORD_CASE: :keyword, KEYWORD_CLASS: :keyword, KEYWORD_DEF: :keyword,
      KEYWORD_DEFINED: :keyword, KEYWORD_DO: :keyword,
      KEYWORD_DO_LOOP: :keyword, KEYWORD_ELSE: :keyword,
      KEYWORD_ELSIF: :keyword, KEYWORD_END: :keyword,
      KEYWORD_END_UPCASE: :keyword, KEYWORD_ENSURE: :keyword,
      KEYWORD_FALSE: :builtin, KEYWORD_FOR: :keyword, KEYWORD_IF: :keyword,
      KEYWORD_IF_MODIFIER: :keyword, KEYWORD_IN: :keyword,
      KEYWORD_MODULE: :keyword, KEYWORD_NEXT: :keyword,
      KEYWORD_NIL: :builtin,
      KEYWORD_NOT: :keyword, KEYWORD_OR: :keyword, KEYWORD_REDO: :keyword,
      KEYWORD_RESCUE: :keyword, KEYWORD_RESCUE_MODIFIER: :keyword,
      KEYWORD_RETRY: :keyword, KEYWORD_RETURN: :keyword,
      KEYWORD_SELF: :builtin, KEYWORD_SUPER: :builtin,
      KEYWORD_THEN: :keyword, KEYWORD_TRUE: :builtin,
      KEYWORD_UNDEF: :keyword,
      KEYWORD_UNLESS: :keyword, KEYWORD_UNLESS_MODIFIER: :keyword,
      KEYWORD_UNTIL: :keyword, KEYWORD_UNTIL_MODIFIER: :keyword,
      KEYWORD_WHEN: :keyword, KEYWORD_WHILE: :keyword,
      KEYWORD_WHILE_MODIFIER: :keyword, KEYWORD_YIELD: :keyword,
      KEYWORD___FILE__: :builtin, KEYWORD___LINE__: :builtin,
      KEYWORD___ENCODING__: :builtin,

      # Comments
      COMMENT: :comment, EMBDOC_BEGIN: :comment, EMBDOC_LINE: :comment,
      EMBDOC_END: :comment,

      # Strings and string-like
      STRING_BEGIN: :string, STRING_CONTENT: :string, STRING_END: :string,
      SYMBOL_BEGIN: :string, REGEXP_BEGIN: :string, REGEXP_END: :string,
      HEREDOC_START: :string, HEREDOC_END: :string,
      LABEL: :property,

      # Numbers
      INTEGER: :number, FLOAT: :number,
      INTEGER_RATIONAL: :number, FLOAT_RATIONAL: :number,
      INTEGER_IMAGINARY: :number, FLOAT_IMAGINARY: :number,
      INTEGER_RATIONAL_IMAGINARY: :number, FLOAT_RATIONAL_IMAGINARY: :number,

      # Constants
      CONSTANT: :constant,

      # Variables
      INSTANCE_VARIABLE: :variable, CLASS_VARIABLE: :variable,
      GLOBAL_VARIABLE: :variable,

      # Operators
      PLUS: :operator, MINUS: :operator, STAR: :operator, SLASH: :operator,
      PERCENT: :operator, STAR_STAR: :operator,
      EQUAL: :operator, EQUAL_EQUAL: :operator, BANG_EQUAL: :operator,
      LESS: :operator, GREATER: :operator,
      LESS_EQUAL: :operator, GREATER_EQUAL: :operator,
      LESS_EQUAL_GREATER: :operator, EQUAL_EQUAL_EQUAL: :operator,
      EQUAL_TILDE: :operator, BANG_TILDE: :operator,
      AMPERSAND_AMPERSAND: :operator, PIPE_PIPE: :operator,
      BANG: :operator, TILDE: :operator,
      LESS_LESS: :operator, GREATER_GREATER: :operator,
      AMPERSAND: :operator, PIPE: :operator, CARET: :operator,
      PLUS_EQUAL: :operator, MINUS_EQUAL: :operator,
      STAR_EQUAL: :operator, SLASH_EQUAL: :operator,
      PERCENT_EQUAL: :operator, STAR_STAR_EQUAL: :operator,
      AMPERSAND_EQUAL: :operator, PIPE_EQUAL: :operator,
      CARET_EQUAL: :operator,
      AMPERSAND_AMPERSAND_EQUAL: :operator, PIPE_PIPE_EQUAL: :operator,
      LESS_LESS_EQUAL: :operator, GREATER_GREATER_EQUAL: :operator,
      DOT_DOT: :operator, DOT_DOT_DOT: :operator,
      EQUAL_GREATER: :operator, UMINUS: :operator, UPLUS: :operator,
      USTAR: :operator, USTAR_STAR: :operator, UAMPERSAND: :operator,

      # Punctuation
      DOT: :punctuation, COLON_COLON: :punctuation,
      SEMICOLON: :punctuation, COMMA: :punctuation,
      PARENTHESIS_LEFT: :punctuation, PARENTHESIS_RIGHT: :punctuation,
      BRACKET_LEFT: :punctuation, BRACKET_LEFT_ARRAY: :punctuation,
      BRACKET_RIGHT: :punctuation,
      BRACE_LEFT: :punctuation, BRACE_RIGHT: :punctuation,
      QUESTION_MARK: :punctuation, COLON: :punctuation,
      LAMBDA_BEGIN: :punctuation,

      # Method names (e.g. block_given?, is_a?)
      METHOD_NAME: :function_name,
    }.freeze

    DEFINITION_KEYWORDS = %i[KEYWORD_CLASS KEYWORD_MODULE KEYWORD_DEF].to_set

    LITERAL_BEGIN_TYPES = %i[STRING_BEGIN HEREDOC_START REGEXP_BEGIN EMBDOC_BEGIN].to_set
    LITERAL_END_TYPES = %i[STRING_END HEREDOC_END REGEXP_END EMBDOC_END].to_set

    CONTINUATION_OPERATOR_TYPES = %i[
      PLUS MINUS STAR SLASH PERCENT STAR_STAR
      EQUAL EQUAL_EQUAL BANG_EQUAL
      LESS GREATER LESS_EQUAL GREATER_EQUAL LESS_EQUAL_GREATER
      EQUAL_TILDE BANG_TILDE
      AMPERSAND_AMPERSAND PIPE_PIPE
      BANG TILDE
      LESS_LESS GREATER_GREATER
      AMPERSAND CARET
      PLUS_EQUAL MINUS_EQUAL STAR_EQUAL SLASH_EQUAL PERCENT_EQUAL
      STAR_STAR_EQUAL AMPERSAND_EQUAL PIPE_EQUAL CARET_EQUAL
      AMPERSAND_AMPERSAND_EQUAL PIPE_PIPE_EQUAL
      LESS_LESS_EQUAL GREATER_GREATER_EQUAL
      EQUAL_GREATER
    ].to_set

    BLOCK_END = {
      EMBEXPR_BEGIN: :EMBEXPR_END,
      BRACE_LEFT: :BRACE_RIGHT,
      PARENTHESIS_LEFT: :PARENTHESIS_RIGHT,
      BRACKET_LEFT: :BRACKET_RIGHT,
      BRACKET_LEFT_ARRAY: :BRACKET_RIGHT,
      LAMBDA_BEGIN: :BRACE_RIGHT,
    }

    INDENT_BEG_RE = /^([ \t]*)(class|module|def|if|unless|case|while|until|for|begin)\b/

    def space_width(s)
      s.gsub(/\t/, " " * @buffer[:tab_width]).size
    end

    def beginning_of_indentation
      loop do
        @buffer.re_search_backward(INDENT_BEG_RE)
        space = @buffer.match_string(1)
        if in_literal?(@buffer.point)
          next
        end
        return space_width(space)
      end
    rescue SearchError
      @buffer.beginning_of_buffer
      0
    end

    def lex(source)
      Prism.lex(source).value.filter_map { |token, _state|
        type = token.type
        next if type == :EOF
        loc = token.location
        [[loc.start_line, loc.start_column], type, token.value]
      }
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
        if event == :NEWLINE || event == :IGNORED_NEWLINE
          _, event, text = tokens[-2]
        end
        if event == :STRING_BEGIN ||
            event == :HEREDOC_START ||
            (event == :HEREDOC_END && text.empty?) ||
            event == :REGEXP_BEGIN ||
            event == :STRING_CONTENT ||
            event == :HEREDOC_CONTENT
          return nil
        end
        i, extra_end_count = find_nearest_beginning_token(tokens)
        (line, column), event, = i ? tokens[i] : nil
        if event == :PARENTHESIS_LEFT && tokens.dig(i + 1, 1) != :IGNORED_NEWLINE
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
        _, last_event, = tokens.reverse_each.find { |_, e, _|
          e != :NEWLINE && e != :IGNORED_NEWLINE
        }
        if start_with_period ||
            CONTINUATION_OPERATOR_TYPES.include?(last_event) ||
            last_event == :KEYWORD_AND || last_event == :KEYWORD_OR ||
            last_event == :DOT ||
            (last_event == :COMMA && event != :BRACE_LEFT &&
             event != :PARENTHESIS_LEFT && event != :BRACKET_LEFT &&
             event != :BRACKET_LEFT_ARRAY) ||
            last_event == :LABEL
          indentation += @buffer[:indent_level]
        end
        indentation
      end
    end

    def find_nearest_beginning_token(tokens)
      stack = []
      (tokens.size - 1).downto(0) do |i|
        (line, ), event, text = tokens[i]
        case event
        when :KEYWORD_CLASS, :KEYWORD_MODULE, :KEYWORD_DEF,
          :KEYWORD_IF, :KEYWORD_UNLESS, :KEYWORD_CASE,
          :KEYWORD_DO, :KEYWORD_DO_LOOP, :KEYWORD_FOR,
          :KEYWORD_WHILE, :KEYWORD_UNTIL, :KEYWORD_BEGIN
          if i > 0
            _, prev_event, _ = tokens[i - 1]
            next if prev_event == :SYMBOL_BEGIN
          end
          if event == :KEYWORD_DEF && endless_method_def?(tokens, i)
            next
          end
          if stack.empty?
            return i
          end
          if stack.last != :KEYWORD_END
            raise EditorError, "#{@buffer.name}:#{line}: Unmatched #{text}"
          end
          stack.pop
        when :KEYWORD_END
          if i > 0
            _, prev_event, _ = tokens[i - 1]
            next if prev_event == :SYMBOL_BEGIN
          end
          stack.push(:KEYWORD_END)
        when :BRACE_RIGHT, :PARENTHESIS_RIGHT, :BRACKET_RIGHT, :EMBEXPR_END
          stack.push(event)
        when :BRACE_LEFT, :PARENTHESIS_LEFT, :BRACKET_LEFT,
          :BRACKET_LEFT_ARRAY, :LAMBDA_BEGIN, :EMBEXPR_BEGIN
          if stack.empty?
            return i
          end
          if stack.last != BLOCK_END[event]
            raise EditorError, "#{@buffer.name}:#{line}: Unmatched #{text}"
          end
          stack.pop
        end
      end
      return nil, stack.count { |t| t != :PARENTHESIS_RIGHT && t != :BRACKET_RIGHT }
    end

    def endless_method_def?(tokens, i)
      ts = tokens.drop(i + 1)
      _, event = ts.shift
      return false if event != :IDENTIFIER && event != :METHOD_NAME
      if ts[0][1] == :PARENTHESIS_LEFT
        ts.shift
        count = 1
        while count > 0
          _, event = ts.shift
          return false if event.nil?
          case event
          when :PARENTHESIS_LEFT
            count += 1
          when :PARENTHESIS_RIGHT
            count -= 1
          end
        end
      end
      ts[0][1] == :EQUAL
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

    def in_literal?(byte_offset)
      ensure_prism_tokens
      ensure_literal_levels
      return false if @literal_levels.empty?
      i = @literal_levels.bsearch_index { |offset, _| offset > byte_offset }
      i = i ? i - 1 : @literal_levels.size - 1
      return false if i < 0
      @literal_levels[i][1] > 0
    end

    def ensure_prism_tokens
      return if @prism_version == @buffer.version
      source = @buffer.to_s
      return unless source.valid_encoding?
      @prism_tokens = Prism.lex(source).value
      @prism_version = @buffer.version
      @literal_levels_version = nil
    end

    def ensure_literal_levels
      return if @literal_levels_version == @prism_version
      level = 0
      @literal_levels = []
      @prism_tokens&.each do |token, _state|
        type = token.type
        if LITERAL_BEGIN_TYPES.include?(type)
          level += 1
        elsif LITERAL_END_TYPES.include?(type)
          next if type == :HEREDOC_END && token.value.empty?
          level -= 1
        end
        @literal_levels << [token.location.start_offset, level]
      end
      @literal_levels_version = @prism_version
    end
  end
end
