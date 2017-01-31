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

  def test_split
    Window.current.split
    assert_equal(3, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(12, Window.windows[0].lines)
    assert_equal(true, Window.windows[0].current?)
    assert_equal(false, Window.windows[0].echo_area?)
    assert_equal(12, Window.windows[1].y)
    assert_equal(11, Window.windows[1].lines)
    assert_equal(false, Window.windows[1].current?)
    assert_equal(false, Window.windows[1].echo_area?)
    assert_equal(Window.windows[0].buffer, Window.windows[1].buffer)
    assert_equal(23, Window.windows[2].y)
    assert_equal(1, Window.windows[2].lines)
    assert_equal(false, Window.windows[2].current?)
    assert_equal(true, Window.windows[2].echo_area?)

    Window.current.split
    Window.current.split
    assert_raise(EditorError) do
      Window.current.split
    end
  end

  def test_s_delete_window
    assert_raise(EditorError) do
      Window.delete_window
    end
    Window.current.split
    assert_equal(3, Window.windows.size)
    window = Window.current
    Window.current = Window.echo_area
    assert_raise(EditorError) do
      Window.delete_window
    end
    Window.current = window
    Window.delete_window
    assert_equal(true, window.deleted?)
    assert_equal(2, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(23, Window.windows[0].lines)
    assert_equal(23, Window.windows[1].y)
    assert_equal(1, Window.windows[1].lines)
    assert_equal(Window.windows[0], Window.current)

    Window.current.split
    assert_equal(3, Window.windows.size)
    window = Window.current = Window.windows[1]
    Window.delete_window
    assert_equal(true, window.deleted?)
    assert_equal(2, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(23, Window.windows[0].lines)
    assert_equal(23, Window.windows[1].y)
    assert_equal(1, Window.windows[1].lines)
    assert_equal(Window.windows[0], Window.current)
  end

  def test_s_delete_other_windows
    Window.current = Window.echo_area
    assert_raise(EditorError) do
      Window.delete_other_windows
    end

    window = Window.current = Window.windows[0]
    Window.current.split
    Window.current.split
    assert_equal(4, Window.windows.size)
    Window.delete_other_windows
    assert_equal(false, window.deleted?)
    assert_equal(2, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(23, Window.windows[0].lines)
    assert_equal(23, Window.windows[1].y)
    assert_equal(1, Window.windows[1].lines)
    assert_equal(Window.windows[0], Window.current)
  end
end
