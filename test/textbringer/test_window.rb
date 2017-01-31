require_relative "../test_helper"

class TestWindow < Textbringer::TestCase
  include Textbringer

  def setup
    super
    @window = Window.current
    @lines = Window.lines - 1
    @columns = Window.columns
    @buffer = Buffer.new_buffer("foo")
    @window.buffer = @buffer
  end

  def test_redisplay
    @window.redisplay
    expected_mode_line = format("%-#{@columns}s",
                                "foo [UTF-8/unix] <EOF> 1,1 (Fundamental)")
    assert_match(expected_mode_line, @window.mode_line.contents[0])
    assert(@window.window.contents.all?(&:empty?))

    @buffer.insert("hello world")
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert(@window.window.contents.drop(1).all?(&:empty?))

    @buffer.insert("\n" + "x" * @columns)
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert(@window.window.contents.drop(2).all?(&:empty?))

    @buffer.insert("x" * @columns)
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert_equal("x" * @columns, @window.window.contents[2])
    assert(@window.window.contents.drop(3).all?(&:empty?))

    @buffer.insert("あ" * (@columns / 2))
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert_equal("x" * @columns, @window.window.contents[2])
    assert_equal("あ" * (@columns / 2), @window.window.contents[3])
    assert(@window.window.contents.drop(4).all?(&:empty?))

    @buffer.insert("x" + "い" * (@columns / 2))
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert_equal("x" * @columns, @window.window.contents[2])
    assert_equal("あ" * (@columns / 2), @window.window.contents[3])
    assert_equal("x" + "い" * (@columns / 2 - 1), @window.window.contents[4])
    assert_equal("い", @window.window.contents[5])
    assert(@window.window.contents.drop(6).all?(&:empty?))

    @buffer.insert("\n" * (@lines - 7))
    @buffer.insert("y" * @columns)
    @buffer.insert("z")
    @buffer.backward_char(2)
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert_equal("x" * @columns, @window.window.contents[2])
    assert_equal("あ" * (@columns / 2), @window.window.contents[3])
    assert_equal("x" + "い" * (@columns / 2 - 1), @window.window.contents[4])
    assert_equal("い", @window.window.contents[5])
    assert(@window.window.contents.drop(6).take(@lines - 8).all?(&:empty?))
    assert_equal("y" * @columns, @window.window.contents[@lines - 2])

    @buffer.forward_char
    @window.redisplay
    assert_equal("x" * @columns, @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert_equal("あ" * (@columns / 2), @window.window.contents[2])
    assert_equal("x" + "い" * (@columns / 2 - 1), @window.window.contents[3])
    assert_equal("い", @window.window.contents[4])
    assert(@window.window.contents.drop(5).take(@lines - 8).all?(&:empty?))
    assert_equal("y" * @columns, @window.window.contents[@lines - 3])
    assert_equal("z", @window.window.contents[@lines - 2])
  end
end
