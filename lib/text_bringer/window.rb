# frozen_string_literal: true

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
          c = @buffer.char_after
          if c == "\n"
            @window.clrtoeol
            break if @window.cury == @window.maxy - 1
          end
          @window << escape(c)
          break if @window.cury == @window.maxy - 1 &&
            @window.curx == @window.maxx - 1
          @buffer.forward_char
        end
        if @buffer.point_at_mark?(saved)
          y, x = @window.cury, @window.curx
        end
        @window.setpos(y, x)
        @window.noutrefresh
      end
    end

    def move(y, x)
      @window.move(y, x)
    end

    def resize(num_lines, num_columns)
      @window.resize(num_lines, num_columns)
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
          new_start_loc = @buffer.point
          @buffer.backward_char
          count += beginning_of_line + 1
        end
        if count >= @window.maxy
          @top_of_window.location = new_start_loc
        end
      end
    end

    def escape(s)
      s.gsub(/[\0-\b\v-\x1f]/) { |c|
        "^" + (c.ord ^ 0x40).chr
      }
    end

    def beginning_of_line
      e = @buffer.point
      @buffer.beginning_of_line
      s = @buffer.substring(@buffer.point, e)
      s.display_width / @window.maxx # TODO: should calculate more correctly
    end
  end
end
