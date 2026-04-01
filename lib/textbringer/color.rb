require "curses"

module Textbringer
  module Color
    BASIC_COLORS = {
      "default" => -1,
      "black" => Curses::COLOR_BLACK,
      "red" => Curses::COLOR_RED,
      "green" => Curses::COLOR_GREEN,
      "yellow" => Curses::COLOR_YELLOW,
      "blue" => Curses::COLOR_BLUE,
      "magenta" => Curses::COLOR_MAGENTA,
      "cyan" => Curses::COLOR_CYAN,
      "white" => Curses::COLOR_WHITE,
      "brightblack" => 8,
      "brightred" => 9,
      "brightgreen" => 10,
      "brightyellow" => 11,
      "brightblue" => 12,
      "brightmagenta" => 13,
      "brightcyan" => 14,
      "brightwhite" => 15
    }

    DIRECT_COLOR_THRESHOLD = 256 * 256 * 256

    # Canonical RGB values for basic ANSI colors (xterm defaults),
    # packed as 0xRRGGBB for use in direct color mode.
    BASIC_COLORS_RGB = {
      "default"       => -1,
      "black"         => 0x000000,
      "red"           => 0xCD0000,
      "green"         => 0x00CD00,
      "yellow"        => 0xCDCD00,
      "blue"          => 0x0000EE,
      "magenta"       => 0xCD00CD,
      "cyan"          => 0x00CDCD,
      "white"         => 0xE5E5E5,
      "brightblack"   => 0x7F7F7F,
      "brightred"     => 0xFF0000,
      "brightgreen"   => 0x00FF00,
      "brightyellow"  => 0xFFFF00,
      "brightblue"    => 0x5C5CFF,
      "brightmagenta" => 0xFF00FF,
      "brightcyan"    => 0x00FFFF,
      "brightwhite"   => 0xFFFFFF
    }

    RGBColor = Struct.new(:r, :g, :b, :number)

    ADDITIONAL_COLORS = []
    rgb_values = [0, 0x5F, 0x87, 0xAF, 0xD7, 0xFF]
    rgb_values.product(rgb_values, rgb_values).each_with_index do
      |(r, g, b), i|
      ADDITIONAL_COLORS << RGBColor.new(r, g, b, 16 + i)
    end
    [
      0x08, 0x12, 0x1c, 0x26, 0x30, 0x3A, 0x44, 0x4E, 0x58, 0x62, 0x6C, 0x76,
      0x80, 0x8a, 0x94, 0x9E, 0xA8, 0xB2, 0xBC, 0xC6, 0xD0, 0xDA, 0xE4, 0xEE
    ].each_with_index do |v, i|
      ADDITIONAL_COLORS << RGBColor.new(v, v, v, 232 + i)
    end

    def self.[](name)
      n = find_color_number(name)
      if n < Window.colors
        n
      else
        -1
      end
    end

    def self.direct_color?
      Window.colors >= DIRECT_COLOR_THRESHOLD
    end

    def self.find_color_number(name)
      if name.is_a?(Integer)
        return name
      end
      if direct_color?
        return find_direct_color(name)
      end
      case name
      when /\A\#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})\z/
        r = $1.to_i(16)
        g = $2.to_i(16)
        b = $3.to_i(16)
        ADDITIONAL_COLORS.sort_by { |c|
          (r - c.r) ** 2 + (g - c.g) ** 2 + (b - c.b) ** 2
        }.first.number
      else
        unless BASIC_COLORS.key?(name)
          raise EditorError, "No such color: #{name}"
        end
        BASIC_COLORS[name]
      end
    end

    def self.find_direct_color(name)
      case name
      when /\A\#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})\z/
        r = $1.to_i(16)
        g = $2.to_i(16)
        b = $3.to_i(16)
        (r << 16) | (g << 8) | b
      else
        unless BASIC_COLORS_RGB.key?(name)
          raise EditorError, "No such color: #{name}"
        end
        BASIC_COLORS_RGB[name]
      end
    end
  end
end
