require_relative "../../test_helper"

class TestWindows < Textbringer::TestCase
  def test_resize
    old_lines = Window.lines
    old_columns = Window.columns
    Window.lines = 40
    Window.columns = 60
    begin
      resize_window
      assert_equal(0, Window.windows[0].y)
      assert_equal(0, Window.windows[0].x)
      assert_equal(60, Window.windows[0].columns)
      assert_equal(39, Window.windows[0].lines)
      assert_equal(39, Window.windows[1].y)
      assert_equal(0, Window.windows[1].x)
      assert_equal(60, Window.windows[1].columns)
      assert_equal(1, Window.windows[1].lines)

      split_window
      assert_equal(3, Window.windows.size)
      assert_equal(0, Window.windows[0].y)
      assert_equal(0, Window.windows[0].x)
      assert_equal(60, Window.windows[0].columns)
      assert_equal(20, Window.windows[0].lines)
      assert_equal(20, Window.windows[1].y)
      assert_equal(0, Window.windows[1].x)
      assert_equal(60, Window.windows[1].columns)
      assert_equal(19, Window.windows[1].lines)
      assert_equal(39, Window.windows[2].y)
      assert_equal(0, Window.windows[2].x)
      assert_equal(60, Window.windows[2].columns)
      assert_equal(1, Window.windows[2].lines)

      Window.lines = 24
      other_window
      resize_window
      assert_equal(3, Window.windows.size)
      assert_equal(Window.windows[1], Window.current)
      assert_equal(0, Window.windows[0].y)
      assert_equal(0, Window.windows[0].x)
      assert_equal(60, Window.windows[0].columns)
      assert_equal(20, Window.windows[0].lines)
      assert_equal(20, Window.windows[1].y)
      assert_equal(0, Window.windows[1].x)
      assert_equal(60, Window.windows[1].columns)
      assert_equal(3, Window.windows[1].lines)
      assert_equal(23, Window.windows[2].y)
      assert_equal(0, Window.windows[2].x)
      assert_equal(60, Window.windows[2].columns)
      assert_equal(1, Window.windows[2].lines)

      Window.lines = 23
      resize_window
      assert_equal(2, Window.windows.size)
      assert_equal(Window.windows[0], Window.current)
      assert_equal(0, Window.windows[0].y)
      assert_equal(0, Window.windows[0].x)
      assert_equal(60, Window.windows[0].columns)
      assert_equal(22, Window.windows[0].lines)
      assert_equal(22, Window.windows[1].y)
      assert_equal(0, Window.windows[1].x)
      assert_equal(60, Window.windows[1].columns)
      assert_equal(1, Window.windows[1].lines)
    ensure
      Window.lines = old_lines
      Window.columns = old_columns
    end
  end

  def test_recenter
    (1..100).each do |i|
      insert("line#{i}\n")
    end
    beginning_of_buffer
    20.times do
      Buffer.current.forward_line
    end
    recenter
    Buffer.current.point_to_mark(Window.current.top_of_window)
    assert_equal(10, Buffer.current.current_line)
  end

  def test_scroll_up
    (1..60).each do |i|
      insert("line#{i}\n")
    end
    beginning_of_buffer
    Window.redisplay
    scroll_up
    Window.redisplay
    assert_equal(21, Buffer.current.current_line)
    scroll_up
    Window.redisplay
    assert_equal(41, Buffer.current.current_line)
    assert_raise(EditorError) do
      scroll_up
    end
  end

  def test_scroll_down
    (1..60).each do |i|
      insert("line#{i}\n")
    end
    Window.redisplay
    scroll_down
    Window.redisplay
    assert_equal(41, Buffer.current.current_line)
    scroll_down
    Window.redisplay
    assert_equal(21, Buffer.current.current_line)
    assert_raise(EditorError) do
      scroll_down
    end
  end

  def test_delete_window
    assert_raise(EditorError) do
      delete_window
    end
    split_window
    assert_equal(3, Window.windows.size)
    window = Window.current
    Window.current = Window.echo_area
    assert_raise(EditorError) do
      delete_window
    end
    Window.current = window
    delete_window
    assert_equal(true, window.deleted?)
    assert_equal(2, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(23, Window.windows[0].lines)
    assert_equal(23, Window.windows[1].y)
    assert_equal(1, Window.windows[1].lines)
    assert_equal(Window.windows[0], Window.current)

    split_window
    assert_equal(3, Window.windows.size)
    window = Window.current = Window.windows[1]
    delete_window
    assert_equal(true, window.deleted?)
    assert_equal(2, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(23, Window.windows[0].lines)
    assert_equal(23, Window.windows[1].y)
    assert_equal(1, Window.windows[1].lines)
    assert_equal(Window.windows[0], Window.current)
  end

  def test_delete_other_windows
    Window.current = Window.echo_area
    assert_raise(EditorError) do
      delete_other_windows
    end

    window = Window.current = Window.windows[0]
    split_window
    split_window
    assert_equal(4, Window.windows.size)
    delete_other_windows
    assert_equal(false, window.deleted?)
    assert_equal(2, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(23, Window.windows[0].lines)
    assert_equal(23, Window.windows[1].y)
    assert_equal(1, Window.windows[1].lines)
    assert_equal(Window.windows[0], Window.current)
  end

  def test_split_window
    split_window
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

    split_window
    assert_raise(EditorError) do
      split_window
    end
  end

  def test_other_window
    window = Window.current

    assert_equal(true, window.current?)
    Window.other_window
    assert_equal(true, window.current?)

    split_window
    assert_equal(window, Window.current)
    Window.other_window
    assert_equal(Window.windows[1], Window.current)
    Window.other_window
    assert_equal(window, Window.current)

    split_window
    assert_equal(window, Window.current)
    Window.other_window
    assert_equal(Window.windows[1], Window.current)
    Window.other_window
    assert_equal(Window.windows[2], Window.current)
    Window.other_window
    assert_equal(window, Window.current)

    Window.echo_area.active = true
    Window.other_window
    assert_equal(Window.windows[1], Window.current)
    Window.other_window
    assert_equal(Window.windows[2], Window.current)
    Window.other_window
    assert_equal(Window.windows[3], Window.current)
    Window.other_window
    assert_equal(window, Window.current)
  end

  def test_enlarge_window
    split_window
    split_window
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(6, Window.windows[0].lines)
    assert_equal(6, Window.windows[1].y)
    assert_equal(6, Window.windows[1].lines)
    assert_equal(12, Window.windows[2].y)
    assert_equal(11, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)

    enlarge_window
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(7, Window.windows[0].lines)
    assert_equal(7, Window.windows[1].y)
    assert_equal(5, Window.windows[1].lines)
    assert_equal(12, Window.windows[2].y)
    assert_equal(11, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)

    enlarge_window(5)
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(12, Window.windows[0].lines)
    assert_equal(12, Window.windows[1].y)
    assert_equal(4, Window.windows[1].lines)
    assert_equal(16, Window.windows[2].y)
    assert_equal(7, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)

    enlarge_window(4)
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(15, Window.windows[0].lines)
    assert_equal(15, Window.windows[1].y)
    assert_equal(4, Window.windows[1].lines)
    assert_equal(19, Window.windows[2].y)
    assert_equal(4, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)

    enlarge_window(-5)
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(10, Window.windows[0].lines)
    assert_equal(10, Window.windows[1].y)
    assert_equal(9, Window.windows[1].lines)
    assert_equal(19, Window.windows[2].y)
    assert_equal(4, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)

    other_window
    enlarge_window(2)
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(8, Window.windows[0].lines)
    assert_equal(8, Window.windows[1].y)
    assert_equal(11, Window.windows[1].lines)
    assert_equal(19, Window.windows[2].y)
    assert_equal(4, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)

    other_window
    enlarge_window(3)
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(8, Window.windows[0].lines)
    assert_equal(8, Window.windows[1].y)
    assert_equal(8, Window.windows[1].lines)
    assert_equal(16, Window.windows[2].y)
    assert_equal(7, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)

    enlarge_window(-3)
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(8, Window.windows[0].lines)
    assert_equal(8, Window.windows[1].y)
    assert_equal(11, Window.windows[1].lines)
    assert_equal(19, Window.windows[2].y)
    assert_equal(4, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)
  end

  def test_shrink_window
    split_window
    split_window
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(6, Window.windows[0].lines)
    assert_equal(6, Window.windows[1].y)
    assert_equal(6, Window.windows[1].lines)
    assert_equal(12, Window.windows[2].y)
    assert_equal(11, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)

    shrink_window
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(5, Window.windows[0].lines)
    assert_equal(5, Window.windows[1].y)
    assert_equal(7, Window.windows[1].lines)
    assert_equal(12, Window.windows[2].y)
    assert_equal(11, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)

    shrink_window(-1)
    assert_equal(4, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(6, Window.windows[0].lines)
    assert_equal(6, Window.windows[1].y)
    assert_equal(6, Window.windows[1].lines)
    assert_equal(12, Window.windows[2].y)
    assert_equal(11, Window.windows[2].lines)
    assert_equal(23, Window.windows[3].y)
    assert_equal(1, Window.windows[3].lines)
  end

  def test_shrink_window_if_larger_than_buffer
    insert(<<EOF)
foo
bar
baz
quux
EOF
    split_window
    shrink_window_if_larger_than_buffer
    assert_equal(3, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(5, Window.windows[0].lines)
    assert_equal(5, Window.windows[1].y)
    assert_equal(18, Window.windows[1].lines)
    assert_equal(23, Window.windows[2].y)
    assert_equal(1, Window.windows[2].lines)

    insert("quux\n")
    shrink_window_if_larger_than_buffer
    assert_equal(3, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(5, Window.windows[0].lines)
    assert_equal(5, Window.windows[1].y)
    assert_equal(18, Window.windows[1].lines)
    assert_equal(23, Window.windows[2].y)
    assert_equal(1, Window.windows[2].lines)
  end

  def test_switch_to_buffer
    foo = Buffer.new_buffer("foo")
    bar = Buffer.new_buffer("bar")
    switch_to_buffer(foo)
    assert_equal(foo, Buffer.current)
    assert_equal(foo, Window.current.buffer)
    switch_to_buffer("bar")
    assert_equal(bar, Buffer.current)
    assert_equal(bar, Window.current.buffer)
    
    assert_raise(EditorError) do
      switch_to_buffer("baz")
    end
  end

  def test_kill_buffer
    foo = Buffer.new_buffer("foo")
    switch_to_buffer(foo)
    insert("foo")

    push_keys("no\n")
    kill_buffer("foo")
    assert_equal(foo, Buffer.current)
    assert_equal(foo, Buffer["foo"])

    push_keys("yes\n")
    kill_buffer(foo)
    assert_not_equal(foo, Buffer.current)
    assert_equal(nil, Buffer["foo"])

    buffers = Buffer.to_a
    buffers.each do |buffer|
      kill_buffer(buffer)
    end
    assert_equal("*scratch*", Buffer.current.name)
  end
end
