module Textbringer
  module Terminal
    class Pad
      attr_reader :cury, :curx

      def initialize(lines, columns)
        @lines = lines
        @columns = columns
        @cury = 0
        @curx = 0
        @attrs = 0
        @fg = -1
        @bg = -1
        @buffer = ScreenBuffer.new(lines, columns)
        @closed = false
      end

      def maxy
        @lines
      end

      def maxx
        @columns
      end

      def erase
        @buffer.clear
        @cury = 0
        @curx = 0
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

      def attron(attr)
        @attrs |= attr
      end

      def attroff(attr)
        @attrs &= ~attr
      end

      def clrtoeol
        x = @curx
        while x < @columns
          @buffer[@cury, x] = Cell.new(" ", @attrs, @fg, @bg, false)
          x += 1
        end
      end

      # noutrefresh for Pad takes source/dest rectangle
      def noutrefresh(pad_min_y, pad_min_x, screen_min_y, screen_min_x, screen_max_y, screen_max_x)
        if Terminal.virtual_screen
          height = screen_max_y - screen_min_y + 1
          width = screen_max_x - screen_min_x + 1
          Terminal.virtual_screen.copy_from(
            @buffer, pad_min_y, pad_min_x,
            screen_min_y, screen_min_x,
            height, width
          )
        end
      end

      def redraw
        # No-op; will be refreshed on next noutrefresh
      end

      def close
        @closed = true
      end

      def resize(lines, columns)
        @lines = lines
        @columns = columns
        @buffer = ScreenBuffer.new(lines, columns)
      end

      def move(y, x)
        # Pads don't have screen position; position is set during noutrefresh
      end

      def keypad=(flag)
      end

      def scrollok(flag)
      end

      def idlok(flag)
      end

      def nodelay=(flag)
      end

      def timeout=(ms)
      end
    end
  end
end
