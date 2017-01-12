# frozen_string_literal: true

require_relative "window"

module Textbringer
  class EchoArea < Window
    attr_accessor :prompt

    def initialize(*args)
      super
      @message = nil
      @prompt = ""
    end

    def clear
      @buffer.delete_region(0, @buffer.size)
      @message = nil
      @prompt = ""
    end

    def clear_message
      @message = nil
    end

    def show(message)
      @message = message
    end

    def redisplay
      return if @buffer.nil?
      @buffer.save_point do |saved|
        @window.erase
        @window.move(0, 0)
        if @message
          @window.addstr @message
        else
          @window.addstr @prompt
          @buffer.beginning_of_line
          while !@buffer.end_of_buffer?
            if @buffer.point_at_mark?(saved)
              y, x = @window.getcury, @window.getcurx
            end
            c = @buffer.char_after
            if c == "\n"
              break
            end
            @window.addstr escape(c)
            @buffer.forward_char
          end
          if @buffer.point_at_mark?(saved)
            y, x = @window.getcury, @window.getcurx
          end
          @window.move(y, x)
        end
        @window.noutrefresh
      end
    end

    def redraw
      @window.redrawwin
    end

    def move(y, x)
      @window.mvwin(y, x)
    end

    def resize(num_lines, num_columns)
      @window.resize(num_lines, num_columns)
    end

    private

    def initialize_window(num_lines, num_columns, y, x)
      @window = Ncurses::WINDOW.new(num_lines, num_columns, y, x)
    end
  end
end
