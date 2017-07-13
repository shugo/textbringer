# frozen_string_literal: true

module Textbringer
  module FillExtension
    refine Buffer do
      def fill_region(s = Buffer.current.point, e = Buffer.current.mark)
        s, e = Buffer.region_boundaries(s, e)
        save_excursion do
          str = substring(s, e)
          goto_char(s)
          pos = point
          beginning_of_line
          column = Buffer.display_width(substring(point, pos))
          composite_edit do
            delete_region(s, e)
            insert(fill_string(str, column))
          end
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

      def fill_string(str, column)
        input = StringIO.new(str)
        output = String.new
        fill_column = CONFIG[:fill_column]
        prev_c = nil
        while c = input.getc
          if column < fill_column && c == "\n"
            if /\w/ =~ prev_c
              column = insert_space_between_words(input, output, column)
            end
            next
          end
          if c == "\n"
            column = insert_newline(output)
          else
            w = Buffer.display_width(c)
            if column + w > fill_column || column >= fill_column
              if /\w/ =~ prev_c && /\w/ =~ c
                column = insert_newline_before_word(output, column)
              else
                column = insert_newline(output)
              end
            end
            column = insert_char(output, column, c, w)
          end
          prev_c = c
        end
        output
      end

      def insert_space_between_words(input, output, column)
        c = input.getc
        input.ungetc(c)
        if /\w/ =~ c
          output << " "
          column + 1
        else
          column
        end
      end

      def insert_newline_before_word(output, column)
        if output.sub!(/(?:([^\w \t\n])|(\w)[ \t]+)(\w*)\z/, "\\1\\2\n")
          output << $3
          Buffer.display_width($3)
        else
          column
        end
      end

      def insert_newline(output)
        output << "\n"
        0
      end

      def insert_char(output, column, c, w)
        if column == 0 && /[ \t]/ =~ c
          column
        else
          output << c
          column + w
        end
      end
    end
  end

  module Commands
    using FillExtension

    define_command(:fill_region,
                   doc: "Fill paragraph.") do
      |s = Buffer.current.point, e = Buffer.current.mark|
      Buffer.current.fill_region(s, e)
    end

    define_command(:fill_paragraph,
                   doc: "Fill paragraph.") do
      Buffer.current.fill_paragraph
    end
  end
end
