require "simplecov"
require "test/unit"
require "tmpdir"

SimpleCov.profiles.define "textbringer" do
  add_filter "/test/"
end
SimpleCov.start("textbringer")

if ENV["UPLOAD_TO_CODECOV"]
  require "codecov"
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require "textbringer"

module Textbringer
  class FakeController < Controller
    attr_reader :test_key_buffer
    attr_writer :last_key

    def initialize(*args)
      super
      @test_key_buffer = []
    end

    def read_char_nonblock
      if @test_key_buffer.empty?
        nil
      else
        @test_key_buffer.shift
      end
    end
    alias read_char read_char_nonblock
  end

  class FakeCursesWindow
    attr_reader :cury, :curx, :contents

    def initialize(lines, columns, y, x)
      @lines = lines
      @columns = columns
      @y = y
      @x = x
      @curx = 0
      @cury = 0
      @contents = @lines.times.map { String.new }
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
      if @curx > @columns
        raise RangeError, "Out of window: #{@curx} > #{@columns}"
      end
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

  module PDCurses
    self.dll_loaded = true

    @key_modifiers = 0

    def PDCurses.PDC_save_key_modifiers(flag)
    end

    def PDCurses.PDC_get_key_modifiers
      @key_modifiers
    end

    def PDCurses.PDC_set_key_modifiers(key_modifiers)
      @key_modifiers = key_modifiers
    end
  end
  
  class Window
    @fake_lines = 24
    @fake_columns = 80

    class << self
      undef lines
      def lines
        @fake_lines
      end

      def lines=(lines)
        @fake_lines = lines
      end

      undef columns
      def columns
        @fake_columns
      end

      def columns=(columns)
        @fake_columns = columns
      end

      undef beep
      def beep
      end

      undef update
      def update
      end

      def setup_for_test
        @@windows.clear
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
      end
    end

    private

    undef initialize_window
    def initialize_window(num_lines, num_columns, y, x)
      @window = FakeCursesWindow.new(num_lines - 1, num_columns, y, x)
      @mode_line = FakeCursesWindow.new(1, num_columns, y + num_lines - 1, x)
    end
  end

  class EchoArea
    private

    undef initialize_window
    def initialize_window(num_lines, num_columns, y, x)
      @window = FakeCursesWindow.new(num_lines, num_columns, y, x)
    end
  end

  class TestCase < Test::Unit::TestCase
    def setup
      Controller.current = FakeController.new
      Buffer.kill_em_all
      KILL_RING.clear
      Window.setup_for_test
    end

    private

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
      if /mswin32|mingw32/ =~ RUBY_PLATFORM
        omit(&block)
      else
        yield
      end
    end
  end
end

include Textbringer
include Commands
