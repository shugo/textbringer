require "stringio"

module Textbringer
  module FillExtension
    class Filler
      GRAPH = /(?=[\u{0000}-\u{00FF}])[[:graph:]]/

      def initialize(column, prefix)
        @column = column
        @prefix = prefix
        @prefix_width = Buffer.display_width(prefix)
        @fill_column = CONFIG[:fill_column]
        @output = +""
        @prev_c = nil
        @bol = column == 0
      end

      def fill(str)
        input = StringIO.new(str)
        if @bol && (indent = str[/\A[ \t]+/])
          @output << indent
          @column = Buffer.display_width(indent)
          @bol = false
          input.seek(indent.bytesize)
        end
        while c = input.getc
          if c == "\n"
            skip_blanks(input)
            if input.eof?
              insert_newline("")
            elsif @column < @fill_column
              if GRAPH.match?(@prev_c)
                insert_space_between_words(input)
              end
              next
            else
              insert_newline(@prefix)
            end
          else
            w = Buffer.display_width(c)
            if @column + w > @fill_column || @column >= @fill_column
              if /\w/.match?(@prev_c) && /\w/.match?(c)
                insert_newline_before_word
              else
                insert_newline(@prefix)
              end
            end
            insert_char(c, w)
          end
          @prev_c = c
        end
        @output
      end

      private

      def skip_blanks(input)
        while c = input.getc
          if !/[ \t]/.match?(c)
            input.ungetc(c)
            break
          end
        end
      end

      def insert_space_between_words(input)
        c = input.getc
        input.ungetc(c)
        if GRAPH.match?(c)
          @output << " "
          @column += 1
        end
      end

      def insert_newline_before_word
        m = @output.match(/(?:([^\w \t\n])|(\w)[ \t]+)(\w*)\z/)
        return if m.nil?
        word = m[3]
        @output[m.begin(0)..] = "#{m[1]}#{m[2]}\n#{@prefix}#{word}"
        @column = @prefix_width + Buffer.display_width(word)
        @bol = false
      end

      def insert_newline(prefix)
        return if @bol
        @output.sub!(/[ \t]+\z/, "")
        @output << "\n" << prefix
        @column = Buffer.display_width(prefix)
        @bol = true
      end

      def insert_char(c, w)
        if @bol && /[ \t]/.match?(c)
          return
        end
        @output << c
        @column += w
        @bol = false
      end
    end

    refine Buffer do
      def fill_region(s = Buffer.current.point, e = Buffer.current.mark)
        s, e = Buffer.region_boundaries(s, e)
        save_excursion do
          str = substring(s, e)
          goto_char(s)
          pos = point
          beginning_of_line
          column = Buffer.display_width(substring(point, pos))
          prefix = fill_prefix(substring(point, e))
          replace(Filler.new(column, prefix).fill(str), start: s, end: e)
        end
      end

      def fill_paragraph
        beginning_of_line
        while !beginning_of_buffer? &&
            !looking_at?(/^[ \t]*$/)
          backward_line
        end
        while looking_at?(/^[ \t]*$/)
          forward_line
        end
        s = point
        begin
          forward_line
        end while !end_of_buffer? && !looking_at?(/^[ \t]*$/)
        if beginning_of_line?
          backward_char
        end
        fill_region(s, point)
      end

      private

      # The indentation of the second line, or of the first line when
      # there is no second line, is the prefix of every line after the
      # first, as with adaptive-fill-mode in Emacs.  The first line keeps
      # its own indentation.
      def fill_prefix(str)
        first, second = str.lines
        line = second && !second.match?(/\A[ \t]*\n?\z/) ? second : first
        line ? line[/\A[ \t]*/] : ""
      end
    end
  end

  module Commands
    using FillExtension

    define_command(:fill_region,
                   doc: "Fill region.") do
      |s = Buffer.current.point, e = Buffer.current.mark|
      Buffer.current.fill_region(s, e)
    end

    define_command(:fill_paragraph,
                   doc: "Fill paragraph.") do
      Buffer.current.fill_paragraph
    end
  end
end
