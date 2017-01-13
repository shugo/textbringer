# frozen_string_literal: true

require "ncursesw"
require "unicode/display_width"
require_relative "buffer"

module Textbringer
  class Window
    KEY_NAMES = {}
    Ncurses.constants.grep(/\AKEY_/).each do |name|
      KEY_NAMES[Ncurses.const_get(name)] =
        name.slice(/\AKEY_(.*)/, 1).downcase.intern
    end

    UTF8_CHAR_LEN = Hash.new(1)
    [
      [0xc0..0xdf, 2],
      [0xe0..0xef, 3],
      [0xf0..0xf4, 4]
    ].each do |range, len|
      range.each do |i|
        UTF8_CHAR_LEN[i] = len
      end
    end

    @@windows = []
    @@current = nil
    @@echo_area = nil

    def self.windows
      @@windows
    end

    def self.current
      @@current
    end

    def self.current=(window)
      @@current = window
    end

    def self.echo_area
      @@echo_area
    end

    def self.start
      Ncurses.initscr
      Ncurses.noecho
      Ncurses.raw
      begin
        @@current =
          Textbringer::Window.new(Window.lines - 1, Window.columns, 0, 0)
        @@windows.push(@@current)
        @@echo_area = Textbringer::EchoArea.new(1, Window.columns,
                                                Window.lines - 1, 0)
        yield
      ensure
        Ncurses.echo
        Ncurses.noraw
        Ncurses.endwin
      end
    end

    def self.redisplay
      if current != echo_area
        echo_area.redisplay
      end
      current.redisplay
      update
    end

    def self.update
      Ncurses.doupdate
    end

    def self.lines
      Ncurses.LINES
    end

    def self.columns
      Ncurses.COLS
    end

    def self.resize
      @@windows.first.resize(Window.lines - 1, Window.columns)
      @@echo_area.move(Window.lines - 1, 0)
      @@echo_area.resize(1, Window.columns)
    end

    def self.beep
      Ncurses.beep
    end

    attr_reader :buffer

    def initialize(num_lines, num_columns, y, x)
      initialize_window(num_lines, num_columns, y, x)
      @window.keypad(true)
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
      @window.getmaxy
    end

    def columns
      @window.getmaxx
    end

    def getch
      key = @window.getch
      if key > 0xff
        KEY_NAMES[key]
      else
        len = UTF8_CHAR_LEN[key]
        if len == 1
          key
        else
          buf = [key]
          (len - 1).times do
            c = @window.getch
            raise "Malformed UTF-8 input" if c.nil? || c < 0x80 || c > 0xbf
            buf.push(c)
          end
          s = buf.pack("C*").force_encoding(Encoding::UTF_8)
          if s.valid_encoding?
            s.ord
          else
            raise "Malformed UTF-8 input"
          end
        end
      end
    end

    def redisplay
      return if @buffer.nil?
      redisplay_mode_line
      @buffer.save_point do |saved|
        framer
        y = x = 0
        @buffer.point_to_mark(@top_of_window)
        @window.erase
        @window.move(0, 0)
        while !@buffer.end_of_buffer?
          if @buffer.point_at_mark?(saved)
            y, x = @window.getcury, @window.getcurx
          end
          c = @buffer.char_after
          if c == "\n"
            @window.clrtoeol
            break if @window.getcury == lines - 1
          end
          @window.addstr(escape(c))
          break if @window.getcury == lines - 1 &&
            @window.getcurx == columns - 1
          @buffer.forward_char
        end
        @buffer.mark_to_point(@bottom_of_window)
        if @buffer.point_at_mark?(saved)
          y, x = @window.getcury, @window.getcurx
        end
        @window.move(y, x)
        @window.noutrefresh
      end
    end
    
    def redraw
      @window.redrawwin
      @mode_line.redrawwin
    end

    def move(y, x)
      @window.mvwin(y, x)
      @mode_line.mvwin(y + @window.getmaxy, x)
    end

    def resize(num_lines, num_columns)
      @window.resize(num_lines - 1, num_columns)
      @mode_line.mvwin(@window.getbegy + num_lines - 1, @window.getbegx)
      @mode_line.resize(1, num_columns)
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

    def initialize_window(num_lines, num_columns, y, x)
      @window = Ncurses::WINDOW.new(num_lines - 1, num_columns, y, x)
      @mode_line = Ncurses::WINDOW.new(1, num_columns, y + num_lines - 1, x)
    end

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
      @mode_line.move(0, 0)
      @mode_line.attron(Ncurses::A_REVERSE)
      @mode_line.addstr(@buffer.name)
      @mode_line.addstr(" ")
      @mode_line.addstr("[+]") if @buffer.modified?
      @mode_line.addstr("[#{@buffer.file_encoding.name}]")
      @mode_line.addstr("[#{@buffer.file_format}]")
      @mode_line.addstr(" " * (@mode_line.getmaxx - @mode_line.getcurx))
      @mode_line.attroff(Ncurses::A_REVERSE)
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
