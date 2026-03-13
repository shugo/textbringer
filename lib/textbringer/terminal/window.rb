module Textbringer
  module Terminal
    class Window
      attr_reader :cury, :curx

      def initialize(lines, columns, y, x)
        @lines = lines
        @columns = columns
        @y = y
        @x = x
        @cury = 0
        @curx = 0
        @attrs = 0
        @fg = -1
        @bg = -1
        @buffer = ScreenBuffer.new(lines, columns)
        @keypad = false
        @nodelay = false
        @timeout_ms = -1
        @input_reader = nil
        @closed = false
      end

      def keypad=(flag)
        @keypad = flag
      end

      def scrollok(flag)
        # Not needed for our implementation
      end

      def idlok(flag)
        # Not needed for our implementation
      end

      def nodelay=(flag)
        @nodelay = flag
      end

      def timeout=(ms)
        @timeout_ms = ms
      end

      def maxy
        @lines
      end

      def maxx
        @columns
      end

      def move(y, x)
        @y = y
        @x = x
      end

      def resize(lines, columns)
        @lines = lines
        @columns = columns
        @buffer = ScreenBuffer.new(lines, columns)
      end

      def erase
        @buffer.clear
        @cury = 0
        @curx = 0
      end

      def clrtoeol
        x = @curx
        while x < @columns
          @buffer[@cury, x] = Cell.new(" ", @attrs, @fg, @bg, false)
          x += 1
        end
      end

      def setpos(y, x)
        @cury = y
        @curx = x
      end

      def addstr(s)
        s.each_char do |c|
          break if @cury >= @lines
          w = Buffer.display_width(c)
          if @curx + w > @columns
            # Wrap or clip
            if @cury + 1 >= @lines
              break
            end
            @cury += 1
            @curx = 0
          end
          @buffer[@cury, @curx] = Cell.new(c, @attrs, @fg, @bg, false)
          if w == 2 && @curx + 1 < @columns
            @buffer[@cury, @curx + 1] = Cell.new("", @attrs, @fg, @bg, true)
          end
          @curx += w
          if @curx >= @columns
            if @cury + 1 < @lines
              @cury += 1
              @curx = 0
            end
          end
        end
      end

      def attr_set(attrs, pair)
        pair_info = Terminal.pair_info(pair)
        @attrs = attrs
        @fg = pair_info ? pair_info[0] : -1
        @bg = pair_info ? pair_info[1] : -1
      end

      def attrset(attrs)
        @attrs = attrs & ~COLOR_PAIR_MASK
        pair = (attrs & COLOR_PAIR_MASK) >> COLOR_PAIR_SHIFT
        pair_info = Terminal.pair_info(pair)
        @fg = pair_info ? pair_info[0] : -1
        @bg = pair_info ? pair_info[1] : -1
      end

      def noutrefresh
        # Copy our local buffer to the global virtual screen
        if Terminal.virtual_screen
          @buffer.lines.times do |dy|
            @buffer.cols.times do |dx|
              sy = @y + dy
              sx = @x + dx
              if sy < Terminal.virtual_screen.lines && sx < Terminal.virtual_screen.cols
                Terminal.virtual_screen[sy, sx] = @buffer[dy, dx].dup
              end
            end
          end
        end
      end

      def redraw
        noutrefresh
      end

      def close
        @closed = true
      end

      def get_char
        reader = Terminal.input_reader
        return nil unless reader
        reader.get_char(
          blocking: !@nodelay,
          timeout_ms: @timeout_ms
        )
      end
    end
  end
end
