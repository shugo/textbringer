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
        prev_c = nil
        while c = input.getc
          if column < fill_column && c == "\n"
            if /\w/ =~ prev_c
              next_c = input.getc
              input.ungetc(next_c)
              if /\w/ =~ next_c
                output << " "
                column += 1
              end
            end
            next
          end
          if c == "\n"
            output << c
            column = 0
          else
            w = Buffer.display_width(c)
            if column + w > fill_column || column >= fill_column
              if /\w/ =~ prev_c && /\w/ =~ c
                if output.sub!(/([^\w\n])(\w*)\z/, "\\1\n")
                  output << $2
                  column = Buffer.display_width($2)
                end
              else
                output << "\n"
                column = 0
              end
            end
            output << c
            column += w
          end
          prev_c = c
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
      if buffer.beginning_of_line?
        buffer.backward_char
      end
      fill_region(s, buffer.point)
    end
  end
end
