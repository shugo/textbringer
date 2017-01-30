# frozen_string_literal: true

require "ripper"

module Textbringer
  CONFIG[:ruby_indent_level] = 2
  CONFIG[:ruby_indent_tabs_mode] = false

  class RubyMode < ProgrammingMode
    self.file_name_pattern = /\A(?:.*\.(?:rb|ru|rake|thor)|
                              (?:Gem|Rake|Cap|Thor|Vagrant|Guard|Pod)file)\z/ix
    self.interpreter_name_pattern = /ruby/i

    def initialize(buffer)
      super(buffer)
      @buffer[:indent_tabs_mode] = CONFIG[:ruby_indent_tabs_mode]
    end

    # Return true if modified.
    def indent_line
      result = false
      level = calculate_indentation
      @buffer.save_excursion do
        @buffer.beginning_of_line
        has_space = @buffer.looking_at?(/[ \t]+/)
        if has_space
          s = @buffer.match_string(0)
          break if /\t/ !~ s && s.size == level
          @buffer.delete_region(@buffer.match_beginning(0),
                                @buffer.match_end(0))
        else
          break if level == 0
        end
        @buffer.indent_to(level)
        if has_space
          @buffer.merge_undo(2)
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

    def compile
      cmd = read_from_minibuffer("Compile: ", default: default_compile_command)
      shell_execute(cmd, "*Ruby compile result*")
      backtrace_mode
    end

    def symbol_pattern
      /[\p{Letter}\p{Number}_$@!?]/
    end

    private

    def calculate_indentation
      if @buffer.current_line == 1
        return 0
      end
      @buffer.save_excursion do
        @buffer.beginning_of_line
        bol_pos = @buffer.point
        tokens = Ripper.lex(@buffer.substring(@buffer.point_min,
                                              @buffer.point))
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
          indentation = base_indentation + @buffer[:ruby_indent_level]
        end
        _, last_event, last_text = tokens.reverse_each.find { |_, e, _|
          e != :on_sp && e != :on_nl && e != :on_ignored_nl
        }
        if (last_event == :on_op && last_text != "|") ||
            last_event == :on_period ||
            last_event == :on_comma
          indentation += @buffer[:ruby_indent_level]
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

    def default_compile_command
      @buffer[:ruby_compile_command] ||
        if File.exist?("Rakefile")
          prefix = File.exist?("Gemfile") ? "bundle exec " : ""
          prefix + "rake"
        else
          "ruby " + @buffer.file_name
        end
    end

    def toggle_test
      case @buffer.file_name
      when %r'(.*)/test/(.*/)?test_(.*?)\.rb\z'
        base = $1
        namespace = $2
        name = $3
        if namespace
          paths = Dir.glob("#{base}/{lib,app}/**/#{namespace}#{name}.rb")
          if !paths.empty?
            find_file(paths.first)
            return
          end
        end
        paths = Dir.glob("#{base}/{lib,app}/**/#{name}.rb")
        if !paths.empty?
          find_file(paths.first)
          return
        end
        raise EditorError, "Test subject not found"
      when %r'(.*)/(?:lib|app)/(.*/)?(.*?)\.rb\z'
        base = $1
        namespace = $2
        name = $3
        if namespace
          paths = Dir.glob("#{base}/test/**/#{namespace}test_#{name}.rb")
          if !paths.empty?
            find_file(paths.first)
            return
          end
        end
        paths = Dir.glob("#{base}/test/**/test_#{name}.rb")
        if !paths.empty?
          find_file(paths.first)
          return
        end
        raise EditorError, "Test not found"
      else
        raise EditorError, "Unknown file type"
      end
    end
  end
end
