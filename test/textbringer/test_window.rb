require_relative "../test_helper"

class TestWindow < Test::Unit::TestCase
  include Textbringer

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

    def method_missing(mid, *args)
    end
  end

  class ::Textbringer::Window
    private

    def initialize_window(num_lines, num_columns, y, x)
      @window = FakeCursesWindow.new(num_lines - 1, num_columns, y, x)
      @mode_line = FakeCursesWindow.new(1, num_columns, y + num_lines - 1, x)
    end
  end

  def setup
    @lines = 23
    @columns = 80
    @y = 5
    @x = 0
    @buffer = Buffer.new(name: "foo")
    @window = Window.new(@lines, @columns, @y, @x)
    @window.buffer = @buffer
  end

  def teardown
    Buffer.kill_em_all
    KILL_RING.clear
  end

  def test_redisplay
    @window.redisplay
    expected_mode_line = format("%-#{@columns}s",
                                "foo [UTF-8/unix] <EOF> 1,1 (Fundamental)")
    assert_match(expected_mode_line, @window.mode_line.contents.first)
    assert(@window.window.contents.all?(&:empty?))
    @buffer.insert("hello world")
    @window.redisplay
    assert_equal("hello world", @window.window.contents.first)
    assert(@window.window.contents.drop(1).all?(&:empty?))
  end
end
