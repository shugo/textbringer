# frozen_string_literal: true

require "text_bringer/window"

module TextBringer
  class EchoArea < Window
    def initialize(*args)
      super
      @message = ""
    end

    def clear
      @message = ""
    end

    def show(message)
      @message = message
    end

    def redisplay
      @buffer.save_point do |saved|
        @window.erase
        @window.setpos(0, 0)
        @window << @message
        @buffer.beginning_of_line
        while !@buffer.end_of_buffer?
          if @buffer.point_at_mark?(saved)
            y, x = @window.cury, @window.curx
          end
          c = @buffer.char_after
          if c == "\n"
            break
          end
          @window << c
          @buffer.forward_char
        end
        if @buffer.point_at_mark?(saved)
          y, x = @window.cury, @window.curx
        end
        @window.setpos(y, x)
        @window.noutrefresh
      end
    end
  end
end
