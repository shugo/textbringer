# frozen_string_literal: true

require "curses"
require "unicode/display_width"

module Textbringer
  class Window
    KEY_NAMES = {}
    Curses.constants.grep(/\AKEY_/).each do |name|
      KEY_NAMES[Curses.const_get(name)] =
        name.slice(/\AKEY_(.*)/, 1).downcase.intern
    end

    UTF8_CHAR_LEN =
      Buffer::UTF8_CHAR_LEN.each_with_object(Hash.new(1)) { |(k, v), h|
        h[k.ord] = v
      }

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
      @@current.save_point if @@current && !@@current.deleted?
      @@current = window
      @@current.restore_point
      Buffer.current = window.buffer
    end

    def self.delete_window
      if @@current.echo_area?
        raise EditorError, "Can't delete the echo area"
      end
      if @@windows.size == 2
        raise EditorError, "Can't delete the sole window"
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
        raise EditorError, "Can't expand the echo area to full screen"
      end
      @@windows.delete_if do |window|
        if window.current? || window.echo_area?
          false
        else
          window.delete
          true
        end
      end
      @@current.move(0, 0)
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
      Curses.init_screen
      Curses.noecho
      Curses.raw
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
        Curses.echo
        Curses.noraw
        Curses.close_screen
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
      Curses.doupdate
    end

    def self.lines
      Curses.lines
    end

    def self.columns
      Curses.cols
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
      Curses.beep
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
      @window.idlok(true)
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
      if @buffer[:top_of_window]
        @top_of_window.location = @buffer[:top_of_window].location
      end
      @bottom_of_window = @buffer.new_mark(@buffer.point_min)
      if @buffer[:bottom_of_window]
        @bottom_of_window.location = @buffer[:bottom_of_window].location
      end
      @point_mark = @buffer.new_mark
    end

    def save_point
      @buffer[:top_of_window] ||= @buffer.new_mark
      @buffer[:top_of_window].location = @top_of_window.location
      @buffer[:bottom_of_window] ||= @buffer.new_mark
      @buffer[:bottom_of_window].location = @bottom_of_window.location
      @buffer.mark_to_point(@point_mark)
    end

    def restore_point
      @buffer.point_to_mark(@point_mark)
    end

    def current?
      self == @@current
    end

    def getch
      key = @window.getch.ord
      if key.nil?
        nil
      elsif key > 0xff
        KEY_NAMES[key]
      else
        len = UTF8_CHAR_LEN[key]
        if len == 1
          key
        else
          buf = [key]
          (len - 1).times do
            c = @window.getch
            if c.nil? || c < 0x80 || c > 0xbf
              raise EditorError, "Malformed UTF-8 input" 
            end
            buf.push(c)
          end
          s = buf.pack("C*").force_encoding(Encoding::UTF_8)
          if s.valid_encoding?
            s.ord
          else
            raise EditorError, "Malformed UTF-8 input"
          end
        end
      end
    end

    def getch_nonblock
      @window.nodelay(true)
      begin
        getch
      ensure
        @window.nodelay(false)
      end
    end

    def wait_input(msecs)
      @window.timeout(msecs)
      begin
        c = @window.getch
        if c && c >= 0
          Curses.ungetch(c)
        end
        c
      ensure
        @window.timeout(-1)
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
        @window.setpos(0, 0)
        if current? && @buffer.visible_mark &&
           @buffer.point_after_mark?(@buffer.visible_mark)
          @window.attron(Curses::A_REVERSE)
        end
        while !@buffer.end_of_buffer?
          if @buffer.point_at_mark?(point)
            y, x = @window.cury, @window.curx
            if current? && @buffer.visible_mark
              if @buffer.point_after_mark?(@buffer.visible_mark)
                @window.attroff(Curses::A_REVERSE)
              elsif @buffer.point_before_mark?(@buffer.visible_mark)
                @window.attron(Curses::A_REVERSE)
              end
            end
          end
          if current? && @buffer.visible_mark &&
             @buffer.point_at_mark?(@buffer.visible_mark)
            if @buffer.point_after_mark?(point)
              @window.attroff(Curses::A_REVERSE)
            elsif @buffer.point_before_mark?(point)
              @window.attron(Curses::A_REVERSE)
            end
          end
          c = @buffer.char_after
          if c == "\n"
            @window.clrtoeol
            break if @window.cury == lines - 2   # lines include mode line
          elsif c == "\t"
            n = calc_tab_width(@window.curx)
            c = " " * n
          else
            c = escape(c)
          end
          @window.addstr(c)
          break if @window.cury == lines - 2 &&  # lines include mode line
            @window.curx == columns
          @buffer.forward_char
        end
        if current? && @buffer.visible_mark
          @window.attroff(Curses::A_REVERSE)
        end
        @buffer.mark_to_point(@bottom_of_window)
        if @buffer.point_at_mark?(point)
          y, x = @window.cury, @window.curx
        end
        if x == columns - 1
          c = @buffer.char_after(point.location)
          if c && Buffer.display_width(c) > 1
            y += 1
            x = 0
          end
        end
        @window.setpos(y, x)
        @window.noutrefresh
      end
    end
    
    def redraw
      @window.noutrefresh
      @mode_line.noutrefresh
    end

    def move(y, x)
      @y = y
      @x = x
      @window.move(y, x)
      @mode_line.move(y + @window.maxy, x)
    end

    def resize(lines, columns)
      @lines = lines
      @columns = columns
      @window.resize(lines - 1, columns)
      @mode_line.move(@y + lines - 1, @x)
      @mode_line.resize(1, columns)
    end

    def recenter
      @buffer.save_point do |saved|
        max = (lines - 1) / 2
        count = beginning_of_line_and_count(max)
        while count < max
          break if @buffer.point == 0
          @buffer.backward_char
          count += beginning_of_line_and_count(max - count - 1) + 1
        end
        @buffer.mark_to_point(@top_of_window)
      end
    end

    def recenter_if_needed
      if @buffer.point_before_mark?(@top_of_window) ||
         @buffer.point_after_mark?(@bottom_of_window)
        recenter
      end
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
        raise EditorError, "Window too small"
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
      @window = Curses::Window.new(num_lines - 1, num_columns, y, x)
      @mode_line = Curses::Window.new(1, num_columns, y + num_lines - 1, x)
    end

    def framer
      @buffer.save_point do |saved|
        max = lines - 1   # lines include mode line
        count = beginning_of_line_and_count(max)
        new_start_loc = @buffer.point
        if @buffer.point_before_mark?(@top_of_window)
          @buffer.mark_to_point(@top_of_window)
          return
        end
        while count < max
          break if @buffer.point_at_mark?(@top_of_window)
          break if @buffer.point == 0
          new_start_loc = @buffer.point
          @buffer.backward_char
          count += beginning_of_line_and_count(max - count - 1) + 1
        end
        if count >= lines - 1     # lines include mode line
          @top_of_window.location = new_start_loc
        end
      end
    end

    def redisplay_mode_line
      @mode_line.erase
      @mode_line.setpos(0, 0)
      @mode_line.attron(Curses::A_REVERSE)
      @mode_line.addstr("#{@buffer.name} ")
      @mode_line.addstr("[+]") if @buffer.modified?
      @mode_line.addstr("[RO]") if @buffer.read_only?
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
      @mode_line.addstr(" (#{@buffer.mode&.name || 'None'})")
      @mode_line.addstr(" " * (@mode_line.maxx - @mode_line.curx))
      @mode_line.attroff(Curses::A_REVERSE)
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

    def calc_tab_width(column)
      tw = @buffer[:tab_width]
      n = tw - column % tw
      n.nonzero? || tw
    end

    def beginning_of_line_and_count(max_lines)
      e = @buffer.point
      @buffer.beginning_of_line
      s = @buffer.substring(@buffer.point, e)
      bols = [@buffer.point]
      column = 0
      while @buffer.point < e
        c = @buffer.char_after
        if c == ?\t
          n = calc_tab_width(column)
          str = " " * n
        else
          str = escape(c)
        end
        column += Buffer.display_width(str)
        if column > @columns
          # Don't forward_char if column > @window.columns
          # to handle multibyte characters across the end of lines.
          bols.push(@buffer.point)
          column = 0
        else
          @buffer.forward_char
          if column == @columns
            bols.push(@buffer.point)
            column = 0
          end
        end
      end
      if bols.size > max_lines
        @buffer.goto_char(bols[-max_lines])
        max_lines
      else
        @buffer.goto_char(bols.first)
        bols.size - 1
      end
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
      @buffer.clear
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
        @window.setpos(0, 0)
        if @message
          @window.addstr @message
        else
          @window.addstr @prompt
          @buffer.beginning_of_line
          while !@buffer.end_of_buffer?
            if @buffer.point_at_mark?(saved)
              y, x = @window.cury, @window.curx
            end
            c = @buffer.char_after
            if c == "\n"
              break
            end
            @window.addstr escape(c)
            @buffer.forward_char
          end
          if @buffer.point_at_mark?(saved)
            y, x = @window.cury, @window.curx
          end
          @window.setpos(y, x)
        end
        @window.noutrefresh
      end
    end

    def redraw
      @window.noutrefresh
    end

    def move(y, x)
      @y = y
      @x = x
      @window.move(y, x)
    end

    def resize(lines, columns)
      @lines = lines
      @columns = columns
      @window.resize(lines, columns)
    end

    private

    def initialize_window(num_lines, num_columns, y, x)
      @window = Curses::Window.new(num_lines, num_columns, y, x)
    end
  end
end
