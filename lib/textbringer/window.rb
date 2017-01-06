# frozen_string_literal: true

require "textbringer/buffer"
require "curses"
require "unicode/display_width"

module Textbringer
  class Window
    def self.start
      Curses.init_screen
      Curses.noecho
      Curses.raw
      begin
        yield
      ensure
        Curses.echo
        Curses.noraw
      end
    end

    def self.update
      Curses.doupdate
    end

    def self.lines
      Curses.lines
    end

    def self.columns
      Curses.cols
    end

    attr_reader :buffer

    def initialize(num_lines, num_columns, y, x)
      @window = Curses::Window.new(num_lines - 1, num_columns, y, x)
      @mode_line = Curses::Window.new(1, num_columns, y + num_lines - 1, x)
      @window.keypad = true
      @window.scrollok(false)
      @buffer = nil
      @top_of_window = nil
      @top_of_windows = {}
      @bottom_of_window = nil
      @bottom_of_windows = {}
    end

    def buffer=(buffer)
      if @top_of_window
        @top_of_window.delete
      end
      if @bottom_of_window
        @bottom_of_window.delete
      end
      @buffer = buffer
      @top_of_window = @top_of_windows[@buffer] ||= @buffer.new_mark
      @bottom_of_window = @bottom_of_windows[@buffer] ||= @buffer.new_mark
    end

    def lines
      @window.maxy
    end

    def columns
      @window.maxx
    end

    def getch
      @window.getch
    end

    def redisplay
      return if @buffer.nil?
      redisplay_mode_line
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
            break if @window.cury == lines - 1
          end
          @window << escape(c)
          break if @window.cury == lines - 1 &&
            @window.curx == columns - 1
          @buffer.forward_char
        end
        @buffer.mark_to_point(@bottom_of_window)
        if @buffer.point_at_mark?(saved)
          y, x = @window.cury, @window.curx
        end
        @window.setpos(y, x)
        @window.noutrefresh
      end
    end

    def move(y, x)
      @window.move(y, x)
      @mode_line.move(y + @window.maxy, x)
    end

    def resize(num_lines, num_columns)
      @window.resize(num_lines - 1, num_columns)
      @mode_line.move(@window.begy + num_lines - 1, @window.begx)
      @mode_line.resize(1, @window.maxx)
    end

    def scroll_up
      @buffer.point_to_mark(@bottom_of_window)
      @buffer.previous_line
      @buffer.beginning_of_line
      @buffer.mark_to_point(@top_of_window)
    end

    def scroll_down
      @buffer.point_to_mark(@top_of_window)
      @buffer.next_line
      @buffer.beginning_of_line
      @top_of_window.location = 0
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
        while count < lines
          break if @buffer.point_at_mark?(@top_of_window)
          break if @buffer.point == 0
          new_start_loc = @buffer.point
          @buffer.backward_char
          count += beginning_of_line + 1
        end
        if count >= lines
          @top_of_window.location = new_start_loc
        end
      end
    end

    def redisplay_mode_line
      @mode_line.erase
      @mode_line.setpos(0, 0)
      @mode_line.attron(Curses::A_REVERSE)
      @mode_line << File.basename(@buffer.name)
      @mode_line << " "
      @mode_line << "[#{@buffer.file_encoding.name}]"
      @mode_line << "[#{@buffer.file_format}]"
      @mode_line << " " * (@mode_line.maxx - @mode_line.curx)
      @mode_line.attroff(Curses::A_REVERSE)
      @mode_line.noutrefresh
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
      # TODO: should calculate more correctly
      Unicode::DisplayWidth.of(s, 2) / columns
    end
  end
end
