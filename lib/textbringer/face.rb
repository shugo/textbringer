require "curses"

module Textbringer
  class Face
    attr_reader :name, :attributes, :color_pair, :text_attrs

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
      resolve_dependents(name)
      @@face_table[name]
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

    UNSET = Object.new.freeze
    private_constant :UNSET

    def update(foreground: nil, background: nil,
               bold: nil, underline: nil, reverse: nil,
               inherit: UNSET)
      unless inherit.equal?(UNSET)
        if inherit && !inherit.is_a?(Symbol)
          raise EditorError,
                "Face inherit: must be a Symbol, got #{inherit.inspect}"
        end
        if inherit && cyclic_inheritance?(@name, inherit)
          raise EditorError,
                "Cyclic face inheritance: #{@name} inherits from #{inherit}"
        end
        @inherit = inherit
      end
      @explicit_foreground = foreground
      @explicit_background = background
      @explicit_bold = bold
      @explicit_underline = underline
      @explicit_reverse = reverse
      resolve_inheritance
      self
    end

    private

    def resolve_inheritance
      parent = @inherit ? self.class[@inherit] : nil
      @foreground = @explicit_foreground || parent&.instance_variable_get(:@foreground) || -1
      @background = @explicit_background || parent&.instance_variable_get(:@background) || -1
      @bold = @explicit_bold.nil? ? (parent&.instance_variable_get(:@bold) || false) : @explicit_bold
      @underline = @explicit_underline.nil? ? (parent&.instance_variable_get(:@underline) || false) : @explicit_underline
      @reverse = @explicit_reverse.nil? ? (parent&.instance_variable_get(:@reverse) || false) : @explicit_reverse
      Curses.init_pair(@color_pair,
                       Color[@foreground], Color[@background])
      @text_attrs = 0
      @text_attrs |= Curses::A_BOLD if @bold
      @text_attrs |= Curses::A_UNDERLINE if @underline
      @text_attrs |= Curses::A_REVERSE if @reverse
      @attributes = Curses.color_pair(@color_pair) | @text_attrs
    end

    def cyclic_inheritance?(name, inherit)
      current = inherit
      while current
        return true if current == name
        face = self.class[current]
        current = face&.instance_variable_get(:@inherit)
      end
      false
    end

    def self.resolve_dependents(name, visited = {})
      visited[name] = true
      @@face_table.each_value do |face|
        if face.instance_variable_get(:@inherit) == name
          face.send(:resolve_inheritance)
          resolve_dependents(face.name, visited) unless visited.key?(face.name)
        end
      end
    end
    private_class_method :resolve_dependents
  end
end
