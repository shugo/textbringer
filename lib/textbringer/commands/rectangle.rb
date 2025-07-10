module Textbringer::Buffer::RectangleMethods
  SHARED_VALUES = {}

  refine Textbringer::Buffer do
    # Returns start_line, start_col, end_line, and end_col of the rectangle region
    # Note that start_col and end_col are 0-origin and width-based (neither 1-origin nor codepoint-based)
    def rectangle_boundaries(s = @point, e = mark)
      s, e = Buffer.region_boundaries(s, e)
      save_excursion do
        goto_char(s)
        start_line = @current_line
        beginning_of_line
        start_col = display_width(substring(@point, s))
        goto_char(e)
        end_line = @current_line
        beginning_of_line
        end_col = display_width(substring(@point, e))

        # Ensure start_col <= end_col
        if start_col > end_col
          start_col, end_col = end_col, start_col
        end
        [start_line, start_col, end_line, end_col]
      end
    end

    def apply_on_rectangle(s = @point, e = mark, reverse: false)
      start_line, start_col, end_line, end_col = rectangle_boundaries(s, e)

      save_excursion do
        composite_edit do
          if reverse
            goto_line(end_line)
          else
            goto_line(start_line)
          end

          loop do
            beginning_of_line
            line_start = @point

            # Move to start column
            col = 0
            while col < start_col && !end_of_line?
              forward_char
              col = display_width(substring(line_start, @point))
            end

            yield(start_col, end_col, col, line_start)

            # Move to next line for forward iteration
            if reverse
              break if @current_line <= start_line
              backward_line
            else
              break if @current_line >= end_line
              forward_line
            end
          end
        end
      end
    end

    def extract_rectangle(s = @point, e = mark)
      lines = []
      apply_on_rectangle(s, e) do |start_col, end_col, col, line_start|
        start_pos = @point
        width = end_col - start_col

        # If we haven't reached start_col, the line is too short
        if col < start_col
          # Line is shorter than start column, extract all spaces
          lines << " " * width
        else
          # Move to end column
          while col < end_col && !end_of_line?
            forward_char
            col = display_width(substring(line_start, @point))
          end
          end_pos = @point

          # Extract the rectangle text for this line
          if end_pos > start_pos
            extracted = substring(start_pos, end_pos)
            # Pad with spaces if the extracted text is shorter than rectangle width
            extracted_width = display_width(extracted)
            if extracted_width < width
              extracted += " " * (width - extracted_width)
            end
            lines << extracted
          else
            lines << " " * width
          end
        end
      end

      lines
    end

    def copy_rectangle(s = @point, e = mark)
      lines = extract_rectangle(s, e)
      SHARED_VALUES[:killed_rectangle] = lines
    end

    def kill_rectangle(s = @point, e = mark)
      copy_rectangle(s, e)
      delete_rectangle(s, e)
    end

    def delete_rectangle(s = @point, e = mark)
      check_read_only_flag

      apply_on_rectangle(s, e, reverse: true) do |start_col, end_col, col, line_start|
        start_pos = @point

        # Only delete if we're within the line bounds
        if col >= start_col
          # Move to end column
          while col < end_col && !end_of_line?
            forward_char
            col = display_width(substring(line_start, @point))
          end
          end_pos = @point

          # Delete the rectangle text for this line
          if end_pos > start_pos
            delete_region(start_pos, end_pos)
          end
        end
      end
    end

    def yank_rectangle
      raise "No rectangle in kill ring" if SHARED_VALUES[:killed_rectangle].nil?
      lines = SHARED_VALUES[:killed_rectangle]
      start_line = @current_line
      start_point = @point
      start_col = save_excursion {
        beginning_of_line
        display_width(substring(@point, start_point))
      }
      composite_edit do
        lines.each_with_index do |line, i|
          goto_line(start_line + i)
          beginning_of_line
          line_start = @point

          # Move to start column, extending line if necessary
          col = 0
          while col < start_col && !end_of_line?
            forward_char
            col = display_width(substring(line_start, @point))
          end

          # If line is shorter than start_col, extend it with spaces
          if col < start_col
            insert(" " * (start_col - col))
          end

          # Insert the rectangle line
          insert(line)
        end
      end
    end

    def open_rectangle(s = @point, e = mark)
      check_read_only_flag
      s, e = Buffer.region_boundaries(s, e)
      composite_edit do
        apply_on_rectangle(s, e) do |start_col, end_col, col, line_start|
          # If line is shorter than start_col, extend it with spaces
          if col < start_col
            insert(" " * (start_col - col))
          end

          # Insert spaces to create the rectangle
          insert(" " * (end_col - start_col))
        end
        goto_char(s)
      end
    end

    def clear_rectangle(s = @point, e = mark)
      check_read_only_flag
      apply_on_rectangle(s, e, reverse: true) do |start_col, end_col, col, line_start|
        start_pos = @point
        if col < start_col
          insert(" " * (end_col - start_col))
        else
          while col < end_col && !end_of_line?
            forward_char
            col = display_width(substring(line_start, @point))
          end
          end_pos = @point

          delete_region(start_pos, end_pos) if end_pos > start_pos
          insert(" " * (end_col - start_col))
        end
      end
    end

    def string_rectangle(str, s = @point, e = mark)
      check_read_only_flag
      apply_on_rectangle(s, e, reverse: true) do |start_col, end_col, col, line_start|
        start_pos = @point
        if col < start_col
          insert(" " * (start_col - col))
          insert(str)
        else
          while col < end_col && !end_of_line?
            forward_char
            col = display_width(substring(line_start, @point))
          end
          end_pos = @point

          delete_region(start_pos, end_pos) if end_pos > start_pos
          insert(str)
        end
      end
    end
  end
end

using Textbringer::Buffer::RectangleMethods

module Textbringer
  module Commands
    define_command(:kill_rectangle,
                   doc: "Kill the text of the region-rectangle, saving its contents as the last killed rectangle.") do
      Buffer.current.kill_rectangle
    end

    define_command(:copy_rectangle_as_kill,
                   doc: "Save the text of the region-rectangle as the last killed rectangle.") do
      Buffer.current.copy_rectangle
    end

    define_command(:delete_rectangle,
                   doc: "Delete the text of the region-rectangle.") do
      Buffer.current.delete_rectangle
    end

    define_command(:yank_rectangle,
                   doc: "Yank the last killed rectangle with its upper left corner at point.") do
      Buffer.current.yank_rectangle
    end

    define_command(:open_rectangle,
                   doc: "Insert blank space to fill the space of the region-rectangle. This pushes the previous contents of the region-rectangle to the right.") do
      Buffer.current.open_rectangle
    end

    define_command(:clear_rectangle,
                   doc: "Clear the region-rectangle by replacing its contents with spaces.") do
      Buffer.current.clear_rectangle
    end

    define_command(:string_rectangle,
                   doc: "Replace rectangle contents with the specified string on each line.") do
      |str = read_from_minibuffer("String rectangle: ")|
      Buffer.current.string_rectangle(str)
    end
  end
end
