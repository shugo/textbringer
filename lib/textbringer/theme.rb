module Textbringer
  class Theme
    DEFAULT_THEME = "catppuccin"

    class Palette
      def initialize
        @colors = {}
      end

      def color(name, hex: nil, ansi: nil)
        @colors[name] = { hex: hex, ansi: ansi }
      end

      def resolve(name, tier)
        c = @colors[name]
        return nil unless c
        tier == :ansi ? c[:ansi] : c[:hex]
      end
    end

    @@themes = {}
    @@current = nil
    @@background_mode = nil

    def self.define(name, &block)
      theme = new(name)
      block.call(theme)
      @@themes[name] = theme
    end

    def self.[](name)
      @@themes[name]
    end

    def self.current
      @@current
    end

    def self.load(name)
      user_path = File.expand_path("~/.textbringer/themes/#{name}.rb")
      if File.exist?(user_path)
        Kernel.load(user_path)
      else
        require "textbringer/themes/#{name}"
      end
      theme = @@themes[name]
      raise EditorError, "Theme '#{name}' not found" unless theme
      theme.activate
    end

    def self.load_default
      return if @@current
      load(DEFAULT_THEME)
    end

    def self.background_mode
      mode = CONFIG[:background_mode]
      return mode if mode == :dark || mode == :light
      @@background_mode || :dark
    end

    def self.detect_background
      @@background_mode = detect_background_via_osc11 ||
                          detect_background_via_colorfgbg ||
                          :dark
    end

    def self.color_tier
      Window.colors >= 256 ? :hex : :ansi
    end

    def initialize(name)
      @name = name
      @palettes = {}
      @face_definitions = []
    end

    attr_reader :name

    def palette(mode, &block)
      p = Palette.new
      block.call(p)
      @palettes[mode] = p
    end

    def face(name, **attrs)
      @face_definitions << [name, attrs]
    end

    def activate
      mode = self.class.background_mode
      tier = self.class.color_tier
      palette = @palettes[mode] || @palettes[:dark] || Palette.new
      @face_definitions.each do |face_name, attrs|
        resolved = {}
        [:foreground, :background].each do |key|
          val = attrs[key]
          if val.is_a?(Symbol)
            color = palette.resolve(val, tier)
            if color
              resolved[key] = color
            else
              raise EditorError,
                    "Unknown palette color :#{val} for #{key} in face #{face_name}"
            end
          elsif val.is_a?(String)
            resolved[key] = val
          end
        end
        [:bold, :underline, :reverse, :inherit].each do |key|
          resolved[key] = attrs[key] if attrs.key?(key)
        end
        Face.define(face_name, **resolved)
      end
      @@current = self
    end

    private_class_method def self.detect_background_via_osc11
      return nil unless $stdin.tty? && $stdout.tty?
      require "io/console"
      $stdin.raw(min: 0, time: 1) do |io|
        $stdout.write("\e]11;?\e\\")
        $stdout.flush
        response = +""
        while (c = io.getc)
          response << c
          break if response.include?("\e\\") || response.include?("\a")
        end
        if response =~ /\e\]11;rgb:([0-9a-f]+)\/([0-9a-f]+)\/([0-9a-f]+)/i
          r = $1[0..1].to_i(16)
          g = $2[0..1].to_i(16)
          b = $3[0..1].to_i(16)
          luminance = 0.299 * r + 0.587 * g + 0.114 * b
          luminance < 128 ? :dark : :light
        end
      end
    rescue
      nil
    end

    private_class_method def self.detect_background_via_colorfgbg
      colorfgbg = ENV["COLORFGBG"]
      return nil unless colorfgbg
      bg = colorfgbg.split(";").last.to_i
      bg <= 6 || bg == 8 ? :dark : :light
    end
  end
end
