require "set"
require "prism"
require_relative "ruby_nesting_parser"

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
      @prism_ast = nil
      @prism_parse_lex_result = nil
      @prism_method_name_locs = nil
      @literal_levels = nil
      @literal_levels_version = nil
      @nesting_by_line = nil
    end

    def forward_definition(n = number_prefix_arg || 1)
      tokens = filter_prism_tokens_line_and_type
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
      tokens = filter_prism_tokens_line_and_type.reverse
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
      ensure_method_name_locs
      base_pos = ctx.buffer.point_min
      hl_start = ctx.highlight_start
      hl_end = ctx.highlight_end
      in_symbol = false
      after_class_or_module = false
      @prism_tokens.each do |token_info|
        token = token_info[0]
        type = token.type
        offset = token.location.start_offset
        length = token.location.length
        pos = base_pos + offset
        pos_end = pos + length
        break if pos >= hl_end
        if pos_end > hl_start
          face_name = PRISM_TOKEN_FACES[type]
          if in_symbol
            face_name = :string if face_name.nil? || face_name == :constant ||
              face_name == :keyword || face_name == :operator
          elsif @prism_method_name_locs.key?(offset)
            face_name = :function_name
          elsif face_name == :constant &&
              (after_class_or_module || token.location.slice.match?(/\p{Lower}/))
            face_name = :type
          end
          if face_name && (face = Face[face_name])
            ctx.highlight(pos, pos_end, face)
          end
        end
        in_symbol = type == :SYMBOL_BEGIN
        after_class_or_module = (type == :KEYWORD_CLASS || type == :KEYWORD_MODULE) ||
          (after_class_or_module && !(type == :NEWLINE || type == :SEMICOLON))
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
      PERCENT_LOWER_I: :string, PERCENT_UPPER_I: :string,
      PERCENT_LOWER_W: :string, PERCENT_UPPER_W: :string,
      PERCENT_LOWER_X: :string,
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

    OPERATORS = %i(!= !~ =~ == === <=> > >= < <= & | ^ >> << - + % / * ** -@ +@ ~ ! [] []=)

    FREE_INDENT_EVENTS = %i[on_tstring_beg on_backtick on_regexp_beg on_symbeg].to_set

    def space_width(s)
      s.gsub(/\t/, " " * @buffer[:tab_width]).size
    end

    def calculate_indentation
      return 0 if @buffer.current_line == 1
      ensure_nesting_by_line
      return 0 if @nesting_by_line.nil? || @nesting_by_line.empty?

      target_line = @buffer.current_line
      line_index = target_line - 1

      if line_index >= @nesting_by_line.size
        # After the last parsed line - use last line's next_opens
        _, last_next_opens, _ = @nesting_by_line.last
        prev_opens = next_opens = last_next_opens
        min_depth = prev_opens.size
      else
        prev_opens, next_opens, min_depth = @nesting_by_line[line_index]
      end

      prev_open_elem = prev_opens&.last

      # Inside string/regexp/heredoc → no auto-indent
      if FREE_INDENT_EVENTS.include?(prev_open_elem&.event)
        return nil
      end
      if prev_open_elem&.event == :on_heredoc_beg
        return nil
      end

      # Parenthesis alignment: foo(123,\n    456)
      if prev_open_elem&.event == :on_lparen
        paren_line = prev_open_elem.pos[0]
        paren_col = prev_open_elem.pos[1]
        if paren_has_args_on_same_line?(paren_line, paren_col)
          return paren_col + 1
        end
      end

      # Base indent from stable nesting depth
      indent_level = calc_indent_level(prev_opens.take(min_depth))
      indent = indent_level * @buffer[:indent_level]

      # Compute base_indent (cosmetic offset from actual code indentation)
      base_indent = compute_base_indent(prev_open_elem, line_index)

      indentation = base_indent + indent

      # Handle extra unmatched closers (end/}/]/))
      if prev_opens.empty?
        extra_count = count_extra_closers_before(target_line)
        if extra_count > 0
          indentation -= extra_count * @buffer[:indent_level]
        end
      end

      # Continuation lines
      if continuation_line?(target_line, prev_open_elem)
        indentation += @buffer[:indent_level]
      end

      indentation
    end

    def calc_indent_level(opens)
      indent_level = 0
      opens&.each do |elem|
        case elem.event
        when :on_heredoc_beg
          # skip
        when :on_tstring_beg, :on_regexp_beg, :on_symbeg, :on_backtick
          indent_level += 1 if elem.tok.start_with?("%")
        when :on_embdoc_beg
          indent_level = 0
        else
          indent_level += 1
        end
      end
      indent_level
    end

    def indent_difference(line_index)
      loop do
        return 0 if line_index < 0 || line_index >= @nesting_by_line.size
        prev_opens, _next_opens, min_depth = @nesting_by_line[line_index]
        open_elem = prev_opens&.last
        if !open_elem || (open_elem.event != :on_heredoc_beg &&
                          !FREE_INDENT_EVENTS.include?(open_elem.event))
          il = calc_indent_level(prev_opens.take(min_depth))
          calculated_indent = il * @buffer[:indent_level]
          actual_indent = actual_indentation_at_line(line_index + 1)
          return actual_indent - calculated_indent
        elsif open_elem.event == :on_heredoc_beg && !open_elem.tok.match?(/^<<[-~]/)
          return 0
        end
        line_index = open_elem.pos[0] - 1
      end
    end

    def compute_base_indent(prev_open_elem, line_index)
      if prev_open_elem
        # Start at the opener's line, trace back through continuations
        li = trace_back_through_continuations(prev_open_elem.pos[0])
        # Then trace back through nesting chain
        while li >= 0 && li < @nesting_by_line.size
          po, _, _ = @nesting_by_line[li]
          outer = po&.last
          if outer.nil?
            return [0, indent_difference(li)].max
          end
          outer_line = outer.pos[0] - 1
          if outer_line < li
            li = outer_line
          else
            return [0, indent_difference(li)].max
          end
        end
        0
      else
        find_base_indent_at_toplevel(line_index)
      end
    end

    def trace_back_through_continuations(line_number)
      li = line_number - 1  # convert to 0-indexed
      while li > 0
        prev_line = li  # 1-indexed line number of previous line
        if line_ends_with_comma?(prev_line)
          li -= 1
        else
          break
        end
      end
      li
    end

    def line_ends_with_comma?(line_number)
      ensure_prism_tokens
      last_event = nil
      @prism_tokens.each do |token, _state|
        loc = token.location
        next if loc.start_line != line_number
        type = token.type
        next if type == :NEWLINE || type == :IGNORED_NEWLINE ||
          type == :COMMENT || type == :EOF
        last_event = type
      end
      last_event == :COMMA
    end

    def find_base_indent_at_toplevel(line_index)
      # First, search for a line with nesting context
      (line_index - 1).downto(0) do |i|
        prev_opens, next_opens, _ = @nesting_by_line[i]
        if !prev_opens.empty?
          origin_elem = prev_opens.first
          return [0, indent_difference(origin_elem.pos[0] - 1)].max
        elsif !next_opens.empty?
          origin_elem = next_opens.first
          return [0, indent_difference(origin_elem.pos[0] - 1)].max
        end
      end
      # Fall back: use nearest non-empty line's actual indentation
      (line_index - 1).downto(0) do |i|
        if line_has_content?(i + 1)
          return actual_indentation_at_line(i + 1)
        end
      end
      0
    end

    def line_has_content?(line_number)
      @buffer.save_excursion do
        @buffer.goto_line(line_number)
        @buffer.looking_at?(/[ \t]*\S/)
      end
    end

    def count_extra_closers_before(target_line)
      return 0 unless @prism_parse_lex_result
      @prism_parse_lex_result.errors.count { |e|
        e.type == :unexpected_token_ignore &&
          e.location.start_line <= target_line
      }
    end

    def actual_indentation_at_line(line_number)
      @buffer.save_excursion do
        @buffer.goto_line(line_number)
        @buffer.looking_at?(/[ \t]*/)
        space_width(@buffer.match_string(0))
      end
    end

    def paren_has_args_on_same_line?(paren_line, paren_col)
      ensure_prism_tokens
      found_paren = false
      @prism_tokens.each do |token, _state|
        loc = token.location
        if !found_paren
          if loc.start_line == paren_line &&
              loc.start_column == paren_col &&
              token.type == :PARENTHESIS_LEFT
            found_paren = true
          end
          next
        end
        next if token.type == :EOF
        return token.type != :IGNORED_NEWLINE && token.type != :NEWLINE &&
          loc.start_line == paren_line
      end
      false
    end

    def continuation_line?(target_line, prev_open_elem)
      start_with_period = @buffer.save_excursion {
        @buffer.beginning_of_line
        @buffer.looking_at?(/[ \t]*\./)
      }
      return true if start_with_period

      prev_line = target_line - 1
      return false if prev_line < 1

      ensure_prism_tokens
      last_event = nil
      @prism_tokens.each do |token, _state|
        loc = token.location
        next if loc.start_line > prev_line
        next if loc.start_line < prev_line
        type = token.type
        next if type == :NEWLINE || type == :IGNORED_NEWLINE ||
          type == :COMMENT || type == :EOF
        last_event = type
      end

      return false if last_event.nil?

      if CONTINUATION_OPERATOR_TYPES.include?(last_event) ||
          last_event == :KEYWORD_AND || last_event == :KEYWORD_OR ||
          last_event == :DOT || last_event == :LABEL
        return true
      end

      if last_event == :COMMA
        if prev_open_elem.nil? ||
            !%i[on_lbrace on_lparen bracket on_lbracket].include?(prev_open_elem.event)
          return true
        end
      end

      false
    end

    def ensure_nesting_by_line
      ensure_prism_tokens
      return if @nesting_by_line && @nesting_version == @prism_version
      if @prism_parse_lex_result
        @nesting_by_line = RubyNestingParser.parse_by_line(@prism_parse_lex_result)
      else
        @nesting_by_line = nil
      end
      @nesting_version = @prism_version
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

    def filter_prism_tokens_line_and_type
      ensure_prism_tokens
      @prism_tokens.filter_map { |token, _state|
        type = token.type
        next if type == :EOF
        [token.location.start_line, type]
      }
    end

    def ensure_prism_tokens
      return if @prism_version == @buffer.version
      source = @buffer.to_s
      if source.valid_encoding?
        @prism_parse_lex_result = Prism.parse_lex(source)
        @prism_ast, @prism_tokens = @prism_parse_lex_result.value
      else
        @prism_parse_lex_result = nil
        @prism_ast = nil
        @prism_tokens = []
      end
      @prism_method_name_locs = nil
      @prism_version = @buffer.version
      @literal_levels_version = nil
      @nesting_by_line = nil
    end

    def ensure_method_name_locs
      return if @prism_method_name_locs
      @prism_method_name_locs = {}
      return unless @prism_ast
      collect_method_name_locs(@prism_ast)
    end

    def collect_method_name_locs(node)
      if node.type == :def_node
        @prism_method_name_locs[node.name_loc.start_offset] = true
      elsif node.type == :alias_method_node
        add_alias_method_name_locs(node.new_name)
        add_alias_method_name_locs(node.old_name)
      elsif (node.type == :call_node &&
             !(node.call_operator_loc.nil? && OPERATORS.include?(node.name)) &&          # exclude operators
             !((node.call_operator_loc.nil? || node.call_operator_loc.slice == "::") &&  # exclude constants
               /\A\p{Upper}/.match?(node.name))) ||
          node.type == :call_operator_write_node ||
          node.type == :call_and_write_node ||
          node.type == :call_or_write_node
        @prism_method_name_locs[node.message_loc.start_offset] = true
      end
      node.compact_child_nodes.each { |child| collect_method_name_locs(child) }
    end

    def add_alias_method_name_locs(node)
      if node.type == :symbol_node && node.opening_loc.nil?
        @prism_method_name_locs[node.value_loc.start_offset] = true
      end
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
