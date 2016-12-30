require "text_bringer/buffer"
require "curses"

module TextBringer
  class Window
    def initialize(buffer, num_lines, num_cols, y, x)
      @buffer = buffer
      @num_lines = num_lines
      @num_columns = num_cols
      @point_lines = @num_lines / 2
      @window = Curses::Window.new(@num_lines, @num_columns, y, x)
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
      saved = @buffer.new_mark
      begin
        framer
        y = x = 0
        @buffer.point_to_mark(@top_of_window)
        @window.erase
        @window.setpos(0, 0)
        while !@buffer.end_of_buffer? &&
            @window.cury < @window.maxy ||
            (@window.cury == @window.maxy && @window.curx < @window.maxx)
          if @buffer.point_at_mark?(saved)
            y, x = @window.cury, @window.curx
          end
          c = @buffer.get_string(1)
          if c == "\n"
            @window.clrtoeol
          end
          @window << c
          @buffer.forward_char
        end
        if @buffer.point_at_mark?(saved)
          y, x = @window.cury, @window.curx
        end
        @window.setpos(y, x)
        @window.refresh
      ensure
        @buffer.point_to_mark(saved)
        saved.delete
      end
    end

    private

    def framer
      saved = @buffer.new_mark
      new_start_loc = nil
      begin
        @buffer.find_first_in_backward("\n")
        if @buffer.point_before_mark?(@top_of_window)
          @buffer.mark_to_point(@top_of_window)
          return
        end
        count = 0
        while count < @num_lines
          break if @buffer.point_at_mark?(@top_of_window)
          break if @buffer.point == 0
          if count >= @point_lines
            new_start_loc = @buffer.point
          end
          @buffer.backward_char
          @buffer.find_first_in_backward("\n")
          count += 1
        end
        if count >= @num_lines
          @top_of_window.location = new_start_loc
        end
      ensure
        @buffer.point_to_mark(saved)
        saved.delete
      end
    end
  end
end
