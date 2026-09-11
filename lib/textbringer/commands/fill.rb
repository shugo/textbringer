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
        @line_start = 0
        @prev_c = nil
        @bol = column == 0
      end

      # head is kept as it is at the start of the first line; body is the
      # text to fill, with the prefix already removed from each line.
      def fill(head, body)
        if !head.empty?
          @output << head
          @line_start = head.size
          @column += Buffer.display_width(head)
          @bol = false
        end
        input = StringIO.new(body)
        while c = input.getc
          if c == "\n"
            skip_blanks(input)
            if input.eof?
              insert_final_newline
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
        m = @output.match(/(?:([^\w \t\n])|(\w)[ \t]+)(\w*)\z/, @line_start)
        return if m.nil?
        word = m[3]
        @output[m.begin(0)..] = "#{m[1]}#{m[2]}\n#{@prefix}#{word}"
        @line_start = @output.size - word.size
        @column = @prefix_width + Buffer.display_width(word)
        @bol = false
      end

      def insert_newline(prefix)
        return if @bol
        @output.sub!(/[ \t]+\z/, "")
        @output << "\n" << prefix
        @line_start = @output.size
        @column = Buffer.display_width(prefix)
        @bol = true
      end

      # The newline that ends the text is kept even on an otherwise empty
      # line, and no prefix follows it.
      def insert_final_newline
        @output.sub!(/[ \t]+\z/, "")
        @output << "\n"
        @line_start = @output.size
        @column = 0
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
          goto_char(s)
          pos = point
          beginning_of_line
          column = Buffer.display_width(substring(point, pos))
          prefix_re = fill_prefix_regexp(comment_line?)
          prefix = fill_prefix(substring(point, e), prefix_re)
          lines = substring(s, e).lines
          head = column == 0 && lines[0] ? lines[0][prefix_re] : ""
          body = lines.each_with_index.map { |line, i|
            i == 0 ? line[head.size..] : line.sub(prefix_re, "")
          }.join
          replace(Filler.new(column, prefix).fill(head, body),
                  start: s, end: e)
        end
      end

      def fill_paragraph
        beginning_of_line
        separator = fill_paragraph_separator(comment_line?)
        while !beginning_of_buffer? && !looking_at?(separator)
          backward_line
        end
        while !end_of_buffer? && looking_at?(separator)
          forward_line
        end
        s = point
        begin
          forward_line
        end while !end_of_buffer? && !looking_at?(separator)
        if beginning_of_line?
          backward_char
        end
        fill_region(s, point)
      end

      private

      # Whether the current line is a line comment of the buffer's mode.
      # Point must be at the beginning of the line.
      def comment_line?
        leader = fill_comment_leader
        !leader.nil? && looking_at?(/[ \t]*#{leader}/)
      end

      def fill_comment_leader
        comment_start = mode&.comment_start
        comment_start && Regexp.quote(comment_start)
      end

      # A line that ends the paragraph: a blank line, or, when filling a
      # comment, any line that is not a comment with something in it.
      def fill_paragraph_separator(comment)
        if comment
          /^(?![ \t]*#{fill_comment_leader}+[ \t]*[^ \t\n])/
        else
          /^[ \t]*$/
        end
      end

      # What is stripped from the start of each line before filling and
      # put back by the prefix: indentation, and the comment leader when
      # filling a comment.
      def fill_prefix_regexp(comment)
        if comment
          /\A[ \t]*(?:#{fill_comment_leader}+[ \t]*)?/
        else
          /\A[ \t]*/
        end
      end

      # The prefix of the second line, or of the first line when there is
      # no second line, is the prefix of every line after the first, as
      # with adaptive-fill-mode in Emacs.  The first line keeps its own
      # prefix.
      def fill_prefix(str, prefix_re)
        first, second = str.lines
        line = second && !second.sub(prefix_re, "").match?(/\A\n?\z/) ?
          second : first
        line ? line[prefix_re] : ""
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
