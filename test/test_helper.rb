require "simplecov"
require "test/unit"
require "tmpdir"

SimpleCov.profiles.define "textbringer" do
  add_filter "/test/"
end
SimpleCov.start("textbringer")

if ENV["UPLOAD_TO_CODECOV"]
  require "codecov"
  module IgnoreFormatError
    def format(*args)
      super(*args)
    rescue => e
      { 
        "error" => {
          "message" => e.message,
          "class" => e.class.name,
          "backtrace" => e.backtrace
        }
      }
    end
  end
  SimpleCov::Formatter::Codecov.send(:prepend, IgnoreFormatError)
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require "textbringer"

module Curses
  @fake_lines = 24
  @fake_cols = 80
  @fake_colors = 256
  @fake_default_colors = [-1, -1]
end

class << Curses
  [
    :init_screen, :close_screen,
    :echo, :noecho,
    :raw, :noraw,
    :nl, :nonl,
    :unget_char,
    :start_color,
    :use_default_colors,
    :init_pair,
    :beep,
    :doupdate
  ].each do |name|
    undef_method name
    define_method(name) do |*args|
    end
  end

  undef lines
  def lines
    @fake_lines
  end

  def lines=(lines)
    @fake_lines = lines
  end

  undef cols
  def cols
    @fake_cols
  end

  def cols=(cols)
    @fake_cols = cols
  end

  undef has_colors?
  def has_colors?
    true
  end

  undef color_pair
  def color_pair(n)
    0
  end

  undef colors
  def colors
    @fake_colors
  end

  def colors=(colors)
    @fake_colors = colors
  end

  if defined?(Curses.assume_default_colors)
    undef assume_default_colors
  end
  def assume_default_colors(fg, bg)
    @fake_default_colors = [fg, bg]
  end

  def default_colors
    @fake_default_colors
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

    private

    def call_read_char_method(read_char_method)
      if @test_key_buffer.empty?
        nil
      else
        @test_key_buffer.shift
      end
    end
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
  ::Curses.send(:remove_const, :Window)
  ::Curses.const_set(:Window, FakeCursesWindow)

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
    class << self
      def lines=(lines)
        Curses.lines = lines
      end

      def columns=(columns)
        Curses.cols = columns
      end

      def setup_for_test
        self.has_colors = true
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
  end

  class TestCase < Test::Unit::TestCase
    setup do
      Controller.current = FakeController.new
      Buffer.global_mark_ring.clear
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
