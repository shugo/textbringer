require "curses"

module Textbringer
  class Face
    attr_reader :name, :attributes

    @@face_table = {}
    @@next_color_pair = 1

    def self.[](name)
      @@face_table[name]
    end

    def self.define(name, **opts)
      if @@face_table.key?(name)
        @@face_table[name].update(**opts)
      else
        @@face_table[name] = new(name, **opts)
      end
    end

    def self.delete(name)
      @@face_table.delete(name)
    end

    def initialize(name, **opts)
      @name = name
      @color_pair = @@next_color_pair
      @@next_color_pair += 1
      update(**opts)
    end

    def update(foreground: -1, background: -1,
               bold: false, underline: false, reverse: false)
      @foreground = foreground
      @background = background
      @bold = bold
      @underline = underline
      @reverse = reverse
      Curses.init_pair(@color_pair,
                       Color[foreground], Color[background])
      @attributes = 0
      @attributes |= Curses.color_pair(@color_pair)
      @attributes |= Curses::A_BOLD if bold
      @attributes |= Curses::A_UNDERLINE if underline
      @attributes |= Curses::A_REVERSE if reverse
      self
    end
  end
end
