module Textbringer
  module Terminal
    # Text attribute constants (bitmask values matching curses conventions)
    A_BOLD      = 1 << 0
    A_UNDERLINE = 1 << 1
    A_REVERSE   = 1 << 2

    # Color pair shift (upper bits store color pair number)
    COLOR_PAIR_SHIFT = 8
    COLOR_PAIR_MASK  = 0xFFFF << COLOR_PAIR_SHIFT

    # Standard ANSI color numbers
    COLOR_BLACK   = 0
    COLOR_RED     = 1
    COLOR_GREEN   = 2
    COLOR_YELLOW  = 3
    COLOR_BLUE    = 4
    COLOR_MAGENTA = 5
    COLOR_CYAN    = 6
    COLOR_WHITE   = 7

    def self.color_pair(n)
      n << COLOR_PAIR_SHIFT
    end

    # Generate SGR (Select Graphic Rendition) escape sequence
    def self.sgr(attrs, fg = -1, bg = -1)
      params = [0]
      params << 1 if (attrs & A_BOLD) != 0
      params << 4 if (attrs & A_UNDERLINE) != 0
      params << 7 if (attrs & A_REVERSE) != 0

      if fg >= 0
        if fg < 8
          params << (30 + fg)
        elsif fg < 16
          params << (90 + fg - 8)
        else
          params << 38 << 5 << fg
        end
      end

      if bg >= 0
        if bg < 8
          params << (40 + bg)
        elsif bg < 16
          params << (100 + bg - 8)
        else
          params << 48 << 5 << bg
        end
      end

      "\e[#{params.join(';')}m"
    end
  end
end
