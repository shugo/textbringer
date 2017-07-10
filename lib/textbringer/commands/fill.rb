# frozen_string_literal: true

module Textbringer
  module Commands
    define_command(:fill_region,
                   doc: "Fill paragraph.") do
      |s = buffer.point, e = buffer.mark|
      s, e = Buffer.region_boundaries(s, e)
      buffer = Buffer.current
      buffer.save_excursion do
        str = buffer.substring(s, e)
        buffer.goto_char(s)
        pos = buffer.point
        buffer.beginning_of_line
        column = Buffer.display_width(buffer.substring(buffer.point, pos))
        input = StringIO.new(str)
        output = String.new
        fill_column = CONFIG[:fill_column]
        while c = input.getc
          if column < fill_column && c == "\n"
            next
          end
          w = Buffer.display_width(c)
          if column + w > fill_column || column >= fill_column
            output << "\n"
            column = 0
          end
          output << c
          column += w
        end
        buffer.composite_edit do
          buffer.delete_region(s, e)
          buffer.insert(output)
        end
      end
    end

    define_command(:fill_paragraph,
                   doc: "Fill paragraph.") do
      buffer = Buffer.current
      buffer.beginning_of_line
      while !buffer.beginning_of_buffer? &&
          !buffer.looking_at?(/^[ \t]*$/)
        buffer.backward_line
      end 
      while buffer.looking_at?(/^[ \t]*$/)
        buffer.forward_line
      end
      s = buffer.point
      begin
        buffer.forward_line
      end while !buffer.end_of_buffer? && !buffer.looking_at?(/^[ \t]*$/)
      fill_region(s, buffer.point)
    end
  end
end
