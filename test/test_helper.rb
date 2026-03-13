require "simplecov"
require "test/unit"
require "tmpdir"

if ENV["RBS_TRACE"] == "1"
  require "rbs-trace"

  trace = RBS::Trace.new
  trace.enable
  SimpleCov.at_exit do
    trace.disable
    trace.save_files(out_dir: "tmp/sig")
  end
end

SimpleCov.profiles.define "textbringer" do
  add_filter "/test/"
end
SimpleCov.start("textbringer")

require "textbringer"

module Textbringer
  module Terminal
    @fake_lines = 24
    @fake_cols = 80
    @fake_colors = 256
    @fake_default_colors = [-1, -1]

    class << self
      [
        :init_screen, :close_screen, :reinit_screen,
        :echo, :noecho,
        :raw, :noraw,
        :nl, :nonl,
        :unget_char,
        :start_color,
        :use_default_colors,
        :beep,
        :doupdate,
        :save_key_modifiers,
      ].each do |name|
        undef_method name if method_defined?(name)
        define_method(name) do |*args|
        end
      end

      undef_method :init_pair if method_defined?(:init_pair)
      define_method(:init_pair) do |*args|
      end

      undef_method :lines
      def lines
        @fake_lines
      end

      def lines=(lines)
        @fake_lines = lines
      end

      undef_method :cols
      def cols
        @fake_cols
      end

      def cols=(cols)
        @fake_cols = cols
      end

      undef_method :has_colors?
      def has_colors?
        true
      end

      undef_method :color_pair
      def color_pair(n)
        0
      end

      undef_method :colors
      def colors
        @fake_colors
      end

      def colors=(colors)
        @fake_colors = colors
      end

      if method_defined?(:assume_default_colors)
        undef_method :assume_default_colors
      end
      def assume_default_colors(fg, bg)
        @fake_default_colors = [fg, bg]
      end

      def default_colors
        @fake_default_colors
      end
    end
  end
end

Textbringer::Window.load_faces

module Textbringer
  class FakeController < Controller
    attr_reader :test_key_buffer
    attr_writer :last_key

    def initialize(*args)
      super
      @test_key_buffer = []
    end

    def read_event
      read_event_nonblock
    end

    def call_next_block
      @next_tick_input.getc
      block = @next_tick_queue_mutex.synchronize {
        @next_tick_queue.shift
      }
      block.call
    end

    private

    def call_read_event_method(read_event_method)
      if @test_key_buffer.empty?
        nil
      else
        @test_key_buffer.shift
      end
    end
  end

  class FakeTerminalWindow
    attr_reader :cury, :curx, :contents

    def initialize(lines, columns, y, x)
      @lines = lines
      @columns = columns
      @y = y
      @x = x
      @curx = 0
      @cury = 0
      @contents = @lines.times.map { +"" }
      @key_buffer = []
    end

    def move(y, x)
      @y = y
      @x = x
    end

    def resize(lines, columns)
      @lines = lines
      @columns = columns
    end

    def maxy
      @lines
    end

    def maxx
      @columns
    end

    def erase
      @contents.each do |line|
        line.clear
      end
    end

    def setpos(y, x)
      @cury = y
      @curx = x
    end

    def addstr(s)
      @contents[@cury].concat(s)
      @curx = Textbringer::Buffer.display_width(@contents[@cury])
    end

    def get_char
      @key_buffer.shift
    end

    def push_key(key)
      @key_buffer.push(key)
    end

    def method_missing(mid, *args)
    end
  end
  Terminal.send(:remove_const, :Window) if Terminal.const_defined?(:Window)
  Terminal.const_set(:Window, FakeTerminalWindow)

  class FakeTerminalPad
    attr_reader :cury, :curx, :contents

    def initialize(lines, columns)
      @lines = lines
      @columns = columns
      @curx = 0
      @cury = 0
      @contents = @lines.times.map { +"" }
      @current_attr = 0
    end

    def erase
      @contents.each do |line|
        line.clear
      end
    end

    def setpos(y, x)
      @cury = y
      @curx = x
    end

    def addstr(s)
      if @cury < @contents.size
        @contents[@cury].concat(s)
        @curx = Textbringer::Buffer.display_width(@contents[@cury])
      end
    end

    def attron(attr)
      @current_attr |= attr
    end

    def attroff(attr)
      @current_attr &= ~attr
    end

    def attrset(attr)
      @current_attr = attr
    end

    def noutrefresh(pad_min_y, pad_min_x, screen_min_y, screen_min_x, screen_max_y, screen_max_x)
      # For testing, just record that this was called
      # Actual display is not needed in tests
    end

    def method_missing(mid, *args)
    end
  end
  Terminal.send(:remove_const, :Pad) if Terminal.const_defined?(:Pad)
  Terminal.const_set(:Pad, FakeTerminalPad)

  class Window
    class << self
      def lines=(lines)
        Terminal.lines = lines
      end

      def columns=(columns)
        Terminal.cols = columns
      end

      def setup_for_test
        self.has_colors = true
        @@list.clear
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
      end

      def clear_list
        @@list.clear
      end
    end
  end

  class TestCase < Test::Unit::TestCase
    setup do
      Controller.current = FakeController.new
      Buffer.global_mark_ring.clear
      Buffer.kill_em_all
      KILL_RING.clear
      Buffer.class_variable_set(:@@killed_rectangle, nil)
      Window.setup_for_test
      @buffer = Buffer.current
    end

    teardown do
      Controller.current.close
    end

    private

    def buffer
      @buffer
    end

    def push_keys(keys)
      if keys.is_a?(String)
        keys = keys.chars
      end
      Controller.current.test_key_buffer.concat(keys)
    end

    def mkcdtmpdir
      Dir.mktmpdir do |dir|
        pwd = Dir.pwd
        Dir.chdir(dir)
        begin
          yield(dir)
        ensure
          Dir.chdir(pwd)
        end
      end
    end

    def omit_on_windows(&block)
      if on_windows?
        omit(&block)
      else
        yield
      end
    end

    def on_windows?
      /mswin|mingw/ =~ RUBY_PLATFORM
    end
  end
end

include Textbringer
include Commands

CONFIG[:t_code_data_dir] = File.expand_path("fixtures/tcode", __dir__)
