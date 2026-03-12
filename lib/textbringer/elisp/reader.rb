module Textbringer
  module Elisp
    class Reader
      class ReadError < StandardError; end

      def initialize(source, filename: "(elisp)")
        @source = source
        @filename = filename
        @pos = 0
        @line = 1
        @column = 0
      end

      def read_all
        forms = []
        skip_whitespace_and_comments
        until eof?
          forms << read_form
          skip_whitespace_and_comments
        end
        forms
      end

      def read_form
        skip_whitespace_and_comments
        raise ReadError, "unexpected end of input at #{location}" if eof?

        case peek
        when "("
          read_list
        when ")"
          raise ReadError, "unexpected ')' at #{location}"
        when "'"
          read_quote(:quote)
        when "`"
          read_quote(:backquote)
        when ","
          read_unquote
        when "#"
          read_hash_dispatch
        when "["
          read_vector
        when "\""
          read_string
        when "?"
          read_character
        else
          read_atom
        end
      end

      private

      def location
        Location.new(filename: @filename, line: @line, column: @column)
      end

      def peek
        @source[@pos]
      end

      def advance
        ch = @source[@pos]
        @pos += 1
        if ch == "\n"
          @line += 1
          @column = 0
        else
          @column += 1
        end
        ch
      end

      def eof?
        @pos >= @source.length
      end

      def skip_whitespace_and_comments
        loop do
          # Skip whitespace
          while !eof? && peek =~ /[\s]/
            advance
          end
          # Skip line comments
          if !eof? && peek == ";"
            advance until eof? || peek == "\n"
          else
            break
          end
        end
      end

      def delimiter?(ch)
        ch.nil? || ch =~ /[\s()\[\];\"]/
      end

      def read_list
        loc = location
        advance # consume '('
        elements = []
        dotted = nil
        skip_whitespace_and_comments
        until eof? || peek == ")"
          if peek == "." && delimiter?(@source[@pos + 1])
            advance # consume '.'
            skip_whitespace_and_comments
            dotted = read_form
            skip_whitespace_and_comments
            break
          end
          elements << read_form
          skip_whitespace_and_comments
        end
        raise ReadError, "unterminated list at #{loc}" if eof?
        advance # consume ')'
        List.new(elements: elements, dotted: dotted, location: loc)
      end

      def read_quote(kind)
        loc = location
        advance # consume ' or `
        form = read_form
        Quoted.new(kind: kind, form: form, location: loc)
      end

      def read_unquote
        loc = location
        advance # consume ','
        splicing = false
        if !eof? && peek == "@"
          advance
          splicing = true
        end
        form = read_form
        Unquote.new(splicing: splicing, form: form, location: loc)
      end

      def read_hash_dispatch
        loc = location
        advance # consume '#'
        raise ReadError, "unexpected end of input after '#' at #{loc}" if eof?
        case peek
        when "'"
          advance # consume '
          form = read_form
          Quoted.new(kind: :function, form: form, location: loc)
        else
          raise ReadError, "unknown reader dispatch '##{peek}' at #{loc}"
        end
      end

      def read_vector
        loc = location
        advance # consume '['
        elements = []
        skip_whitespace_and_comments
        until eof? || peek == "]"
          elements << read_form
          skip_whitespace_and_comments
        end
        raise ReadError, "unterminated vector at #{loc}" if eof?
        advance # consume ']'
        Vector.new(elements: elements, location: loc)
      end

      def read_string
        loc = location
        advance # consume opening "
        str = +""
        until eof? || peek == "\""
          if peek == "\\"
            advance
            raise ReadError, "unterminated string escape at #{loc}" if eof?
            str << read_string_escape
          else
            str << advance
          end
        end
        raise ReadError, "unterminated string at #{loc}" if eof?
        advance # consume closing "
        StringLit.new(value: str.freeze, location: loc)
      end

      def read_string_escape
        ch = advance
        case ch
        when "n" then "\n"
        when "t" then "\t"
        when "r" then "\r"
        when "\\" then "\\"
        when "\"" then "\""
        when "a" then "\a"
        when "b" then "\b"
        when "f" then "\f"
        when "v" then "\v"
        when "0" then "\0"
        when "e" then "\e"
        when "s" then " "
        when "d" then "\x7f"
        when "x"
          hex = +""
          while !eof? && peek =~ /[0-9a-fA-F]/
            hex << advance
          end
          hex.to_i(16).chr(Encoding::UTF_8)
        when "u"
          hex = +""
          while !eof? && peek =~ /[0-9a-fA-F]/ && hex.length < 4
            hex << advance
          end
          hex.to_i(16).chr(Encoding::UTF_8)
        else
          ch
        end
      end

      def read_character
        loc = location
        advance # consume '?'
        raise ReadError, "unexpected end of input after '?' at #{loc}" if eof?
        if peek == "\\"
          advance
          raise ReadError, "unexpected end of input in character literal at #{loc}" if eof?
          code = read_char_escape
        else
          code = advance.ord
        end
        CharLit.new(value: code, location: loc)
      end

      def read_char_escape
        ch = advance
        case ch
        when "C", "^"
          # Control character
          advance if ch == "C" && !eof? && peek == "-"
          raise ReadError, "unexpected end of input in control char at #{location}" if eof?
          if peek == "\\"
            advance
            raise ReadError, "unexpected end of input in control char at #{location}" if eof?
            base = read_char_escape
          else
            base = advance.ord
          end
          base & 0x1f
        when "M"
          # Meta character
          advance if !eof? && peek == "-"
          raise ReadError, "unexpected end of input in meta char at #{location}" if eof?
          if peek == "\\"
            advance
            raise ReadError, "unexpected end of input in meta char at #{location}" if eof?
            base = read_char_escape
          else
            base = advance.ord
          end
          base | 0x80
        when "S"
          # Shift
          advance if !eof? && peek == "-"
          raise ReadError, "unexpected end of input in shift char at #{location}" if eof?
          if peek == "\\"
            advance
            base = read_char_escape
          else
            base = advance.ord
          end
          base
        when "n" then "\n".ord
        when "t" then "\t".ord
        when "r" then "\r".ord
        when "e" then 27
        when "a" then 7
        when "b" then 8
        when "f" then 12
        when "v" then 11
        when "s" then 32
        when "d" then 127
        when "\\" then "\\".ord
        when "x"
          hex = +""
          while !eof? && peek =~ /[0-9a-fA-F]/
            hex << advance
          end
          hex.to_i(16)
        when "0".."7"
          oct = ch
          while !eof? && peek =~ /[0-7]/ && oct.length < 3
            oct << advance
          end
          oct.to_i(8)
        else
          ch.ord
        end
      end

      def read_atom
        loc = location
        token = +""
        until eof? || delimiter?(peek)
          if peek == "\\"
            advance
            token << advance unless eof?
          else
            token << advance
          end
        end

        case token
        when /\A[+-]?\d+\z/
          IntegerLit.new(value: token.to_i, location: loc)
        when /\A[+-]?\d+\.\d*(?:[eE][+-]?\d+)?\z/,
             /\A[+-]?\d*\.\d+(?:[eE][+-]?\d+)?\z/,
             /\A[+-]?\d+[eE][+-]?\d+\z/
          FloatLit.new(value: token.to_f, location: loc)
        when "#x"
          # handled above, but just in case
          IntegerLit.new(value: 0, location: loc)
        when "nil"
          Symbol.new(name: "nil", location: loc)
        when "t"
          Symbol.new(name: "t", location: loc)
        else
          Symbol.new(name: token, location: loc)
        end
      end
    end
  end
end
