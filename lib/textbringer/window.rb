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

    HAVE_GET_KEY_MODIFIERS = defined?(Curses.get_key_modifiers)
    if HAVE_GET_KEY_MODIFIERS
      ALT_NUMBER_BASE = Curses::ALT_0 - ?0.ord
      ALT_ALPHA_BASE = Curses::ALT_A - ?a.ord
    end

    @@started = false
    @@list = []
    @@current = nil
    @@echo_area = nil
    @@has_colors = false

    def self.list(include_echo_area: false)
      if include_echo_area
        @@list.dup
      else
        @@list.reject(&:echo_area?)
      end
    end

    def self.current
      @@current
    end

    def self.current=(window)
      if window.deleted?
        window = @@list.first
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
      if @@list.size == 2
        raise EditorError, "Can't delete the sole window"
      end
      i = @@list.index(@@current)
      if i == 0
        window = @@list[1]
        window.move(0, 0)
      else
        window = @@list[i - 1]
      end
      window.resize(@@current.lines + window.lines, window.columns)
      @@current.delete
      @@list.delete_at(i)
      self.current = window
    end

    def self.delete_other_windows
      if @@current.echo_area?
        raise EditorError, "Can't expand the echo area to full screen"
      end
      @@list.delete_if do |window|
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
      i = @@list.index(@@current)
      begin
        i += 1
        window = @@list[i % @@list.size]
      end while !window.active?
      self.current = window
    end

    def self.echo_area
      @@echo_area
    end

    def self.has_colors=(value)
      @@has_colors = value
    end

    def self.has_colors?
      @@has_colors
    end

    def self.colors
      Curses.colors
    end

    def self.set_default_colors(fg, bg)
      Curses.assume_default_colors(Color[fg], Color[bg])
      Window.redraw
    end

    def self.load_faces
      require_relative "faces/basic"
      require_relative "faces/programming"
    end

    def self.start
      if @@started
        raise EditorError, "Already started"
      end
      Curses.init_screen
      Curses.noecho
      Curses.raw
      Curses.nonl
      self.has_colors = Curses.has_colors?
      if has_colors?
        Curses.start_color
        Curses.use_default_colors
        load_faces
      end
      begin
        window =
          Textbringer::Window.new(Window.lines - 1, Window.columns, 0, 0)
        window.buffer = Buffer.new_buffer("*scratch*")
        @@list.push(window)
        Window.current = window
        @@echo_area = Textbringer::EchoArea.new(1, Window.columns,
                                                Window.lines - 1, 0)
        Buffer.minibuffer.keymap = MINIBUFFER_LOCAL_MAP
        @@echo_area.buffer = Buffer.minibuffer
        @@list.push(@@echo_area)
        @@started = true
        yield
      ensure
        @@list.each do |win|
          win.close
        end
        @@list.clear
        Curses.echo
        Curses.noraw
        Curses.nl
        Curses.close_screen
        @@started = false
      end
    end

    def self.redisplay
      return if Controller.current.executing_keyboard_macro?
      return if Window.current.has_input?
      @@list.each do |window|
        window.redisplay unless window.current?
      end
      current.redisplay
      update
    end

    def self.redraw
      @@list.each do |window|
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
      @@list.delete_if do |window|
        if !window.echo_area? &&
            window.y > Window.lines - CONFIG[:window_min_height]
          window.delete
          true
        else
          false
        end
      end
      @@list.each_with_index do |window, i|
        unless window.echo_area?
          if i < @@list.size - 2
            window.resize(window.lines, Window.columns)
          else
            window.resize(Window.lines - 1 - window.y, Window.columns)
          end
        end
      end
      @@echo_area.move(Window.lines - 1, 0)
      @@echo_area.resize(1, Window.columns)
    end

    def self.beep
      Curses.beep
    end

    attr_reader :buffer, :lines, :columns, :y, :x, :window, :mode_line
    attr_reader :top_of_window, :bottom_of_window

    def initialize(lines, columns, y, x)
      @lines = lines
      @columns = columns
      @y = y
      @x = x
      initialize_window(lines, columns, y, x)
      @window.keypad = true
      @window.scrollok(false)
      @window.idlok(true)
      @buffer = nil
      @top_of_window = nil
      @bottom_of_window = nil
      @point_mark = nil
      @deleted = false
      @raw_key_buffer = []
      @key_buffer = []
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
          Window.current = @@list.first
        end
        delete_marks
        @window.close
        @deleted = true
      end
    end

    def close
      @window.close
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

    def read_event
      key = get_char
      if key.is_a?(Integer)
        if HAVE_GET_KEY_MODIFIERS
          if Curses::ALT_0 <= key && key <= Curses::ALT_9
            @key_buffer.push((key - ALT_NUMBER_BASE).chr)
            return "\e"
          elsif Curses::ALT_A <= key && key <= Curses::ALT_Z
            @key_buffer.push((key - ALT_ALPHA_BASE).chr)
            return "\e"
          end
        end
        KEY_NAMES[key] || key
      else
        key&.encode(Encoding::UTF_8)
      end
    end

    def read_event_nonblock
      @window.nodelay = true
      begin
        read_event
      ensure
        @window.nodelay = false
      end
    end

    def wait_input(msecs)
      if !@raw_key_buffer.empty? || !@key_buffer.empty?
        return @raw_key_buffer.first || @key_buffer.first
      end
      @window.timeout = msecs
      begin
        c = @window.get_char
        if c
          @raw_key_buffer.push(c)
        end
        c
      ensure
        @window.timeout = -1
      end
    end

    def has_input?
      if !@raw_key_buffer.empty? || !@key_buffer.empty?
        return true
      end
      @window.nodelay = true
      begin
        c = @window.get_char
        if c
          @raw_key_buffer.push(c)
        end
        !c.nil?
      ensure
        @window.nodelay = false
      end
    end

    def highlight
      @highlight_on = {}
      @highlight_off = {}
      return if !@@has_colors || !CONFIG[:syntax_highlight]
      syntax_table = @buffer.mode.syntax_table
      return if syntax_table.empty?
      if @buffer.bytesize < CONFIG[:highlight_buffer_size_limit]
        base_pos = @buffer.point_min
        s = @buffer.to_s
      else
        base_pos = @buffer.point
        len = columns * (lines - 1) / 2 * 3
        s = @buffer.substring(@buffer.point, @buffer.point + len).scrub("")
      end
      re_str = syntax_table.map { |name, re|
        "(?<#{name}>#{re})"
      }.join("|")
      re = Regexp.new(re_str)
      names = syntax_table.keys
      s.scan(re) do
        b = base_pos + $`.bytesize
        e = b + $&.bytesize
        if b < @buffer.point && @buffer.point < e
          b = @buffer.point
        end
        name = names.find { |n| $~[n] }
        attributes = Face[name]&.attributes
        if attributes
          @highlight_on[b] = attributes
          @highlight_off[e] = attributes
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
        highlight
        @window.erase
        @window.setpos(0, 0)
        @window.attrset(0)
        if current? && @buffer.visible_mark &&
           @buffer.point_after_mark?(@buffer.visible_mark)
          @window.attron(Curses::A_REVERSE)
        end
        while !@buffer.end_of_buffer?
          cury, curx = @window.cury, @window.curx
          if @buffer.point_at_mark?(point)
            y, x = cury, curx
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
          if attrs = @highlight_off[@buffer.point]
            @window.attroff(attrs)
          end
          if attrs = @highlight_on[@buffer.point]
            @window.attron(attrs)
          end
          c = @buffer.char_after
          if c == "\n"
            @window.clrtoeol
            break if cury == lines - 2   # lines include mode line
            @window.setpos(cury + 1, 0)
            @buffer.forward_char
            next
          elsif c == "\t"
            n = calc_tab_width(curx)
            c = " " * n
          else
            c = escape(c)
          end
          if curx < columns - 4
            newx = nil
          else
            newx = curx + Buffer.display_width(c)
            if newx > columns
              if cury == lines - 2
                break
              else
                @window.clrtoeol
                @window.setpos(cury + 1, 0)
              end
            end
          end
          @window.addstr(c)
          break if newx == columns && cury == lines - 2
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
      @window.redraw
      @mode_line.redraw
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
      if @bottom_of_window.location == @buffer.point_max
        raise RangeError, "End of buffer"
      end
      @buffer.point_to_mark(@bottom_of_window)
      @buffer.previous_line
      @buffer.beginning_of_line
      @buffer.mark_to_point(@top_of_window)
    end

    def scroll_down
      if @top_of_window.location == @buffer.point_min
        raise RangeError, "Beginning of buffer"
      end
      @buffer.point_to_mark(@top_of_window)
      @buffer.next_line
      @buffer.beginning_of_line
      @top_of_window.location = 0
    end

    def split
      old_lines = lines
      new_lines = (old_lines / 2.0).ceil
      if new_lines < CONFIG[:window_min_height]
        raise EditorError, "Window too small"
      end
      resize(new_lines, columns)
      new_window = Window.new(old_lines - new_lines, columns, y + new_lines, x)
      new_window.buffer = buffer
      i = @@list.index(self)
      @@list.insert(i + 1, new_window)
    end

    def enlarge(n)
      if n > 0
        max_height = Window.lines -
          CONFIG[:window_min_height] * (@@list.size - 2) - 1
        new_lines = [lines + n, max_height].min
        needed_lines = new_lines - lines
        resize(new_lines, columns)
        i = @@list.index(self)
        indices = (i + 1).upto(@@list.size - 2).to_a +
          (i - 1).downto(0).to_a
        indices.each do |j|
          break if needed_lines == 0
          window = @@list[j]
          extended_lines = [
            window.lines - CONFIG[:window_min_height],
            needed_lines
          ].min
          window.resize(window.lines - extended_lines, window.columns)
          needed_lines -= extended_lines
        end
        y = 0
        @@list.each do |win|
          win.move(y, win.x)
          y += win.lines
        end
      elsif n < 0 && @@list.size > 2
        new_lines = [lines + n, CONFIG[:window_min_height]].max
        diff = lines - new_lines
        resize(new_lines, columns)
        i = @@list.index(self)
        if i < @@list.size - 2
          window = @@list[i + 1]
          window.move(window.y - diff, window.x)
        else
          window = @@list[i - 1]
          move(self.y + diff, self.x)
        end
        window.resize(window.lines + diff, window.columns)
      end
    end

    def shrink(n)
      enlarge(-n)
    end

    def shrink_if_larger_than_buffer
      @buffer.save_point do
        @buffer.end_of_buffer
        @buffer.skip_re_backward(/\s/)
        count = beginning_of_line_and_count(Window.lines) + 1
        while !@buffer.beginning_of_buffer?
          @buffer.backward_char
          count += beginning_of_line_and_count(Window.lines) + 1
        end
        if lines - 1 > count
          shrink(lines - 1 - count)
        end
      end
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
      attrs = @@has_colors ? Face[:mode_line].attributes : Curses::A_REVERSE
      @mode_line.attrset(attrs)
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
      @mode_line.addstr(" " * (columns - @mode_line.curx))
      @mode_line.attrset(0)
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
        s.gsub(/[\0-\b\v-\x1f\x7f]/) { |c|
          "^" + (c.ord ^ 0x40).chr
        }.gsub(/[\x80-\xff]/n) { |c|
          "<%02X>" % c.ord
        }
      else
        s.gsub(/[\0-\b\v-\x1f\x7f]/) { |c|
          "^" + (c.ord ^ 0x40).chr
        }
      end
    end

    def calc_tab_width(column)
      tw = @buffer[:tab_width]
      n = tw - column % tw
      n.nonzero? || tw
    end

    def beginning_of_line_and_count(max_lines, columns = @columns)
      e = @buffer.point
      @buffer.beginning_of_line
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
        if column > columns
          # Don't forward_char if column > columns
          # to handle multibyte characters across the end of lines.
          bols.push(@buffer.point)
          column = 0
        else
          @buffer.forward_char
          if column == columns
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

    def get_char
      if @key_buffer.empty?
        Curses.save_key_modifiers(true) if HAVE_GET_KEY_MODIFIERS
        begin
          need_retry = false
          if @raw_key_buffer.empty?
            key = @window.get_char
          else
            key = @raw_key_buffer.shift
          end
          if HAVE_GET_KEY_MODIFIERS
            mods = Curses.get_key_modifiers
            if key.is_a?(String) && key.ascii_only?
              if (mods & Curses::PDC_KEY_MODIFIER_CONTROL) != 0
                key = key == ?? ? "\x7f" : (key.ord & 0x9f).chr
              end
              if (mods & Curses::PDC_KEY_MODIFIER_ALT) != 0
                if key == "\0"
                  # Alt + `, Alt + < etc. return NUL, so ignore it.
                  need_retry = true
                else
                  @key_buffer.push(key)
                  key = "\e"
                end
              end
            end
          end
        end while need_retry
        key
      else
        @key_buffer.shift
      end
    end
  end

  class EchoArea < Window
    attr_reader :message
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
      @top_of_window.location = @buffer.point_min
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
          @window.addstr(escape(@message))
        else
          prompt = escape(@prompt)
          @window.addstr(prompt)
          framer
          @buffer.point_to_mark(@top_of_window)
          y = x = 0
          while !@buffer.end_of_buffer?
            cury, curx = @window.cury, @window.curx
            if @buffer.point_at_mark?(saved)
              y, x = cury, curx
            end
            c = @buffer.char_after
            if c == "\n"
              break
            end
            s = escape(c)
            newx = curx + Buffer.display_width(s)
            if newx > @columns
              break
            end
            @window.addstr(s)
            break if newx >= @columns
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
      @window.redraw
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

    def escape(s)
      super(s).gsub(/\t/, "^I")
    end

    def framer
      @buffer.save_point do |saved|
        max_width = @columns - @window.curx
        width = 0
        loop do
          c = @buffer.char_after
          if c.nil?
            width += 1
          else
            width += Buffer.display_width(escape(c))
          end
          if width > max_width
            @buffer.forward_char
            break
          elsif width == max_width || @buffer.beginning_of_line? ||
              @buffer.point_at_mark?(@top_of_window)
            break
          end
          @buffer.backward_char
        end
        @top_of_window.location = @buffer.point
      end
    end
  end
end
