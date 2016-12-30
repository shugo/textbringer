require "text_bringer/buffer"
require "curses"

module TextBringer
  class Window
    def initialize(buffer)
      @buffer = buffer
      @num_lines = Curses.lines
      @num_columns = Curses.cols
      @point_lines = @num_lines / 2
      @window = Curses::Window.new(@num_lines, @num_columns, 0, 0)
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
        @window.setpos(0, 0)
        while !@buffer.end_of_buffer? &&
            @window.cury < @window.maxy ||
            (@window.cury == @window.maxy && @window.curx < @window.maxy)
          if @buffer.point_at_mark?(saved)
            y, x = @window.cury, @window.curx
          end
          @window << @buffer.get_string(1)
          @buffer.forward_char
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
        count = 0
        while count < @num_lines
          break if @buffer.point_at_mark?(@top_of_window)
          break if @buffer.point == 0
          if count == @point_lines
            new_start_loc = count
          end
          @buffer.backward_char
          @buffer.find_first_in_backward("\n")
          count += 1
        end
      ensure
        @buffer.point_to_mark(saved)
        saved.delete
      end
    end
  end
end
