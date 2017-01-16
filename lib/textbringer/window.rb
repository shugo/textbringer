# frozen_string_literal: true

require "ncursesw"
require "unicode/display_width"

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
      if window.deleted?
        window = @@windows.first
      end
      @@current&.save_point
      @@current = window
      @@current.restore_point
      Buffer.current = window.buffer
    end

    def self.delete_window
      if @@current.echo_area?
        raise "Can't delete the echo area"
      end
      if @@windows.size == 2
        raise "Can't delete the sole window"
      end
      i = @@windows.index(@@current)
      if i == 0
        window = @@windows[1]
        window.move(0, 0)
      else
        window = @@windows[i - 1]
      end
      window.resize(@@current.lines + window.lines, window.columns)
      @@current.delete
      @@windows.delete_at(i)
      self.current = window
    end

    def self.delete_other_windows
      if @@current.echo_area?
        raise "Can't expand the echo area to full screen"
      end
      @@windows.delete_if do |window|
        if window.current? || window.echo_area?
          false
        else
          window.delete
          true
        end
      end
      @@current.resize(Window.lines - 1, @@current.columns)
    end

    def self.other_window
      i = @@windows.index(@@current)
      begin
        i += 1
        window = @@windows[i % @@windows.size]
      end while !window.active?
      self.current = window
    end

    def self.echo_area
      @@echo_area
    end

    def self.start
      Ncurses.initscr
      Ncurses.noecho
      Ncurses.raw
      begin
        window =
          Textbringer::Window.new(Window.lines - 1, Window.columns, 0, 0)
        window.buffer = Buffer.new_buffer("*scratch*")
        @@windows.push(window)
        Window.current = window
        @@echo_area = Textbringer::EchoArea.new(1, Window.columns,
                                                Window.lines - 1, 0)
  	Buffer.minibuffer.keymap = MINIBUFFER_LOCAL_MAP
	@@echo_area.buffer = Buffer.minibuffer
	@@windows.push(@@echo_area)
        yield
      ensure
        Ncurses.echo
        Ncurses.noraw
        Ncurses.endwin
      end
    end

    def self.redisplay
      @@windows.each do |window|
        window.redisplay unless window.current?
      end
      current.redisplay
      update
    end

    def self.redraw
      @@windows.each do |window|
        window.redraw unless window.current?
      end
      current.redraw
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
      @@windows.delete_if do |window|
        if window.y > Window.lines - 4
          window.delete
          true
        else
          false
        end
      end
      @@windows.each_with_index do |window, i|
        if i < @@windows.size - 1
          window.resize(window.lines, Window.columns)
        else
          window.resize(Window.lines - 1 - window.y, Window.columns)
        end
      end
      @@echo_area.move(Window.lines - 1, 0)
      @@echo_area.resize(1, Window.columns)
    end

    def self.beep
      Ncurses.beep
    end

    attr_reader :buffer, :lines, :columns, :y, :x

    def initialize(lines, columns, y, x)
      @lines = lines
      @columns = columns
      @y = y
      @x = x
      initialize_window(lines, columns, y, x)
      @window.keypad(true)
      @window.scrollok(false)
      @buffer = nil
      @top_of_window = nil
      @bottom_of_window = nil
      @point_mark = nil
      @deleted = false
    end

    def echo_area?
      false
    end

    def active?
      true
    end

    def deleted?
      @deleted
    end

    def delete
      unless @deleted
        if current?
          Window.current = @@windows.first
        end
        delete_marks
        @window.del
        @deleted = true
      end
    end

    def buffer=(buffer)
      delete_marks
      @buffer = buffer
      @top_of_window = @buffer.new_mark(@buffer.point_min)
      @bottom_of_window = @buffer.new_mark(@buffer.point_min)
      @point_mark = @buffer.new_mark
    end

    def save_point
      @buffer.mark_to_point(@point_mark)
    end

    def restore_point
      @buffer.point_to_mark(@point_mark)
    end

    def current?
      self == @@current
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
        if current?
          point = saved
        else
          point = @point_mark
          @buffer.point_to_mark(@point_mark)
        end
        framer
        y = x = 0
        @buffer.point_to_mark(@top_of_window)
        @window.erase
        @window.move(0, 0)
        while !@buffer.end_of_buffer?
          if @buffer.point_at_mark?(point)
            y, x = @window.getcury, @window.getcurx
          end
          c = @buffer.char_after
          if c == "\n"
            @window.clrtoeol
            break if @window.getcury == lines - 2   # lines include mode line
          end
          @window.addstr(escape(c))
          break if @window.getcury == lines - 2 &&  # lines include mode line
            @window.getcurx == columns - 1
          @buffer.forward_char
        end
        @buffer.mark_to_point(@bottom_of_window)
        if @buffer.point_at_mark?(point)
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
      @y = y
      @x = x
      @window.mvwin(y, x)
      @mode_line.mvwin(y + @window.getmaxy, x)
    end

    def resize(lines, columns)
      @lines = lines
      @columns = columns
      @window.resize(lines - 1, columns)
      @mode_line.mvwin(@y + lines - 1, @x)
      @mode_line.resize(1, columns)
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

    def split
      if lines < 6
        raise "Window too small"
      end
      old_lines = lines
      new_lines = (old_lines / 2.0).ceil
      resize(new_lines, columns)
      new_window = Window.new(old_lines - new_lines, columns, y + new_lines, x)
      new_window.buffer = buffer
      i = @@windows.index(self)
      @@windows.insert(i + 1, new_window)
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
        while count < lines - 1   # lines include mode line
          break if @buffer.point_at_mark?(@top_of_window)
          break if @buffer.point == 0
          new_start_loc = @buffer.point
          @buffer.backward_char
          count += beginning_of_line + 1
        end
        if count >= lines - 1     # lines include mode line
          @top_of_window.location = new_start_loc
        end
      end
    end

    def redisplay_mode_line
      @mode_line.erase
      @mode_line.move(0, 0)
      @mode_line.attron(Ncurses::A_REVERSE)
      @mode_line.addstr("#{@buffer.name} ")
      @mode_line.addstr("[+]") if @buffer.modified?
      @mode_line.addstr("[#{@buffer.file_encoding.name}/")
      @mode_line.addstr("#{@buffer.file_format}] ")
      if current? || @buffer.point_at_mark?(@point_mark)
        c = @buffer.char_after
        line = @buffer.current_line
        column = @buffer.current_column
      else
        c = @buffer.char_after(@point_mark.location)
        line, column = @buffer.get_line_and_column(@point_mark.location)
      end
      @mode_line.addstr(unicode_codepoint(c))
      @mode_line.addstr(" #{line},#{column}")
      @mode_line.addstr(" " * (@mode_line.getmaxx - @mode_line.getcurx))
      @mode_line.attroff(Ncurses::A_REVERSE)
      @mode_line.noutrefresh
    end

    def unicode_codepoint(c)
      if c.nil?
        "<EOF>"
      else
        "U+%04X" % c.ord
      end
    end

    def escape(s)
      if @buffer.binary?
        s.gsub(/[\0-\b\v-\x1f]/) { |c|
          "^" + (c.ord ^ 0x40).chr
        }.gsub(/[\x80-\xff]/n) { |c|
          "<%02X>" % c.ord
        }
      else
        s.gsub(/[\0-\b\v-\x1f]/) { |c|
          "^" + (c.ord ^ 0x40).chr
        }
      end
    end

    def beginning_of_line
      e = @buffer.point
      @buffer.beginning_of_line
      s = @buffer.substring(@buffer.point, e)
      # TODO: should calculate more correctly
      Unicode::DisplayWidth.of(s, 2) / columns
    end

    def delete_marks
      if @top_of_window
        @top_of_window.delete
        @top_of_window = nil
      end
      if @bottom_of_window
        @bottom_of_window.delete
        @bottom_of_window = nil
      end
      if @point_mark
        @point_mark.delete
        @point_mark = nil
      end
    end
  end

  class EchoArea < Window
    attr_accessor :prompt
    attr_writer :active

    def initialize(*args)
      super
      @message = nil
      @prompt = ""
      @active = false
    end

    def echo_area?
      true
    end

    def active?
      @active
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
      @y = y
      @x = x
      @window.mvwin(y, x)
    end

    def resize(lines, columns)
      @lines = lines
      @columns = columns
      @window.resize(lines, columns)
    end

    private

    def initialize_window(num_lines, num_columns, y, x)
      @window = Ncurses::WINDOW.new(num_lines, num_columns, y, x)
    end
  end
end
