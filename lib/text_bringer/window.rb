require "text_bringer/buffer"
require "curses"
require "unicode/display_width"

module TextBringer
  class Window
    def initialize(buffer, num_lines, num_columns, y, x)
      @buffer = buffer
      @window = Curses::Window.new(num_lines, num_columns, y, x)
      @window.keypad = true
      @window.scrollok(false)
      @top_of_window = @buffer.new_mark
      @top_of_window.location = 0
      redisplay
    end

    def getch
      @window.getch
    end

    def redisplay
      @buffer.save_point do |saved|
        framer
        y = x = 0
        @buffer.point_to_mark(@top_of_window)
        @window.erase
        @window.setpos(0, 0)
        while !@buffer.end_of_buffer?
          if @buffer.point_at_mark?(saved)
            y, x = @window.cury, @window.curx
          end
          c = @buffer.get_string(1)
          if c == "\n"
            @window.clrtoeol
            break if @window.cury == @window.maxy - 1
          end
          @window << c
          break if @window.cury == @window.maxy - 1 &&
            @window.curx == @window.maxx - 1
          @buffer.forward_char
        end
        if @buffer.point_at_mark?(saved)
          y, x = @window.cury, @window.curx
        end
        @window.setpos(y, x)
        @window.refresh
      end
    end

    private

    def framer
      @buffer.save_point do |saved|
        new_start_loc = nil
        count = beginning_of_line
        if @buffer.point_before_mark?(@top_of_window)
          @buffer.mark_to_point(@top_of_window)
          return
        end
        while count < @window.maxy
          break if @buffer.point_at_mark?(@top_of_window)
          break if @buffer.point == 0
          if count >= @window.maxy / 2
            new_start_loc = @buffer.point
          end
          @buffer.backward_char
          count += beginning_of_line + 1
        end
        if count >= @window.maxy
          @top_of_window.location = new_start_loc
        end
      end
    end

    def beginning_of_line
      e = @buffer.point
      @buffer.find_first_in_backward("\n")
      s = @buffer[@buffer.point...e]
      s.display_width / @window.maxx # TODO: should calculate more correctly
    end
  end
end
