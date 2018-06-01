require_relative "../../test_helper"

class TestWindows < Textbringer::TestCase
  def test_resize
    old_lines = Window.lines
    old_columns = Window.columns
    Window.lines = 40
    Window.columns = 60
    begin
      resize_window
      list = Window.list(include_echo_area: true)
      assert_equal(0, list[0].y)
      assert_equal(0, list[0].x)
      assert_equal(60, list[0].columns)
      assert_equal(39, list[0].lines)
      assert_equal(39, list[1].y)
      assert_equal(0, list[1].x)
      assert_equal(60, list[1].columns)
      assert_equal(1, list[1].lines)

      split_window
      list = Window.list(include_echo_area: true)
      assert_equal(3, list.size)
      assert_equal(0, list[0].y)
      assert_equal(0, list[0].x)
      assert_equal(60, list[0].columns)
      assert_equal(20, list[0].lines)
      assert_equal(20, list[1].y)
      assert_equal(0, list[1].x)
      assert_equal(60, list[1].columns)
      assert_equal(19, list[1].lines)
      assert_equal(39, list[2].y)
      assert_equal(0, list[2].x)
      assert_equal(60, list[2].columns)
      assert_equal(1, list[2].lines)

      Window.lines = 24
      other_window
      resize_window
      list = Window.list(include_echo_area: true)
      assert_equal(3, list.size)
      assert_equal(list[1], Window.current)
      assert_equal(0, list[0].y)
      assert_equal(0, list[0].x)
      assert_equal(60, list[0].columns)
      assert_equal(20, list[0].lines)
      assert_equal(20, list[1].y)
      assert_equal(0, list[1].x)
      assert_equal(60, list[1].columns)
      assert_equal(3, list[1].lines)
      assert_equal(23, list[2].y)
      assert_equal(0, list[2].x)
      assert_equal(60, list[2].columns)
      assert_equal(1, list[2].lines)

      Window.lines = 23
      resize_window
      list = Window.list(include_echo_area: true)
      assert_equal(2, list.size)
      assert_equal(list[0], Window.current)
      assert_equal(0, list[0].y)
      assert_equal(0, list[0].x)
      assert_equal(60, list[0].columns)
      assert_equal(22, list[0].lines)
      assert_equal(22, list[1].y)
      assert_equal(0, list[1].x)
      assert_equal(60, list[1].columns)
      assert_equal(1, list[1].lines)
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
    assert_raise(RangeError) do
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
    assert_raise(RangeError) do
      scroll_down
    end
  end

  def test_delete_window
    assert_raise(EditorError) do
      delete_window
    end
    split_window
    assert_equal(3, Window.list(include_echo_area: true).size)
    window = Window.current
    Window.current = Window.echo_area
    assert_raise(EditorError) do
      delete_window
    end
    Window.current = window
    delete_window
    assert_equal(true, window.deleted?)
    list = Window.list(include_echo_area: true)
    assert_equal(2, list.size)
    assert_equal(0, list[0].y)
    assert_equal(23, list[0].lines)
    assert_equal(23, list[1].y)
    assert_equal(1, list[1].lines)
    assert_equal(Window.list(include_echo_area: true)[0], Window.current)

    split_window
    assert_equal(2, Window.list.size)
    window = Window.current = Window.list(include_echo_area: true)[1]
    delete_window
    assert_equal(true, window.deleted?)
    list = Window.list(include_echo_area: true)
    assert_equal(2, list.size)
    assert_equal(0, list[0].y)
    assert_equal(23, list[0].lines)
    assert_equal(23, list[1].y)
    assert_equal(1, list[1].lines)
    assert_equal(Window.list(include_echo_area: true)[0], Window.current)
  end

  def test_delete_other_windows
    Window.current = Window.echo_area
    assert_raise(EditorError) do
      delete_other_windows
    end

    window = Window.current = Window.list(include_echo_area: true)[0]
    split_window
    split_window
    assert_equal(4, Window.list(include_echo_area: true).size)
    delete_other_windows
    assert_equal(false, window.deleted?)
    list = Window.list(include_echo_area: true)
    assert_equal(2, list.size)
    assert_equal(0, list[0].y)
    assert_equal(23, list[0].lines)
    assert_equal(23, list[1].y)
    assert_equal(1, list[1].lines)
    assert_equal(Window.list(include_echo_area: true)[0], Window.current)
  end

  def test_split_window
    split_window
    list = Window.list(include_echo_area: true)
    assert_equal(3, list.size)
    assert_equal(0, list[0].y)
    assert_equal(12, list[0].lines)
    assert_equal(true, list[0].current?)
    assert_equal(false, list[0].echo_area?)
    assert_equal(12, list[1].y)
    assert_equal(11, list[1].lines)
    assert_equal(false, list[1].current?)
    assert_equal(false, list[1].echo_area?)
    assert_equal(list[0].buffer, list[1].buffer)
    assert_equal(23, list[2].y)
    assert_equal(1, list[2].lines)
    assert_equal(false, list[2].current?)
    assert_equal(true, list[2].echo_area?)

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
    assert_equal(Window.list[1], Window.current)
    Window.other_window
    assert_equal(window, Window.current)

    split_window
    assert_equal(window, Window.current)
    Window.other_window
    assert_equal(Window.list[1], Window.current)
    Window.other_window
    assert_equal(Window.list[2], Window.current)
    Window.other_window
    assert_equal(window, Window.current)

    Window.echo_area.active = true
    Window.other_window
    assert_equal(Window.list[1], Window.current)
    Window.other_window
    assert_equal(Window.list[2], Window.current)
    Window.other_window
    assert_equal(Window.echo_area, Window.current)
    Window.other_window
    assert_equal(window, Window.current)
  end

  def test_enlarge_window
    split_window
    split_window
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(6, list[0].lines)
    assert_equal(6, list[1].y)
    assert_equal(6, list[1].lines)
    assert_equal(12, list[2].y)
    assert_equal(11, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)

    enlarge_window
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(7, list[0].lines)
    assert_equal(7, list[1].y)
    assert_equal(5, list[1].lines)
    assert_equal(12, list[2].y)
    assert_equal(11, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)

    enlarge_window(5)
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(12, list[0].lines)
    assert_equal(12, list[1].y)
    assert_equal(4, list[1].lines)
    assert_equal(16, list[2].y)
    assert_equal(7, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)

    enlarge_window(4)
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(15, list[0].lines)
    assert_equal(15, list[1].y)
    assert_equal(4, list[1].lines)
    assert_equal(19, list[2].y)
    assert_equal(4, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)

    enlarge_window(-5)
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(10, list[0].lines)
    assert_equal(10, list[1].y)
    assert_equal(9, list[1].lines)
    assert_equal(19, list[2].y)
    assert_equal(4, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)

    other_window
    enlarge_window(2)
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(8, list[0].lines)
    assert_equal(8, list[1].y)
    assert_equal(11, list[1].lines)
    assert_equal(19, list[2].y)
    assert_equal(4, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)

    other_window
    enlarge_window(3)
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(8, list[0].lines)
    assert_equal(8, list[1].y)
    assert_equal(8, list[1].lines)
    assert_equal(16, list[2].y)
    assert_equal(7, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)

    enlarge_window(-3)
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(8, list[0].lines)
    assert_equal(8, list[1].y)
    assert_equal(11, list[1].lines)
    assert_equal(19, list[2].y)
    assert_equal(4, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)
  end

  def test_shrink_window
    split_window
    split_window
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(6, list[0].lines)
    assert_equal(6, list[1].y)
    assert_equal(6, list[1].lines)
    assert_equal(12, list[2].y)
    assert_equal(11, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)

    shrink_window
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(5, list[0].lines)
    assert_equal(5, list[1].y)
    assert_equal(7, list[1].lines)
    assert_equal(12, list[2].y)
    assert_equal(11, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)

    shrink_window(-1)
    list = Window.list(include_echo_area: true)
    assert_equal(4, list.size)
    assert_equal(0, list[0].y)
    assert_equal(6, list[0].lines)
    assert_equal(6, list[1].y)
    assert_equal(6, list[1].lines)
    assert_equal(12, list[2].y)
    assert_equal(11, list[2].lines)
    assert_equal(23, list[3].y)
    assert_equal(1, list[3].lines)
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
    list = Window.list(include_echo_area: true)
    assert_equal(3, list.size)
    assert_equal(0, list[0].y)
    assert_equal(5, list[0].lines)
    assert_equal(5, list[1].y)
    assert_equal(18, list[1].lines)
    assert_equal(23, list[2].y)
    assert_equal(1, list[2].lines)

    insert("quux\n")
    shrink_window_if_larger_than_buffer
    list = Window.list(include_echo_area: true)
    assert_equal(3, list.size)
    assert_equal(0, list[0].y)
    assert_equal(5, list[0].lines)
    assert_equal(5, list[1].y)
    assert_equal(18, list[1].lines)
    assert_equal(23, list[2].y)
    assert_equal(1, list[2].lines)
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

  def test_list_buffers
    Buffer.new_buffer("foo")
    Buffer.new_buffer("bar")
    list_buffers
    assert_equal("*Buffer List*", Buffer.current.name)
    assert_equal(<<~EOF.chomp, Buffer.current.to_s)
      *scratch*
      foo
      bar
      *Buffer List*
    EOF
  end

  def test_bury_buffer
    scratch = Buffer["*scratch*"]
    bury_buffer
    assert_equal([scratch], Buffer.list)
    assert_equal(scratch, Buffer.current)
    assert_equal(scratch, Window.current.buffer)
    foo = Buffer.new_buffer("foo")
    bar = Buffer.new_buffer("bar")
    baz = Buffer.new_buffer("baz")
    assert_equal([scratch, foo, bar, baz], Buffer.list)
    assert_equal(scratch, Buffer.current)
    assert_equal(scratch, Window.current.buffer)
    bury_buffer
    assert_equal([foo, bar, baz, scratch], Buffer.list)
    assert_equal(foo, Buffer.current)
    assert_equal(foo, Window.current.buffer)
    bury_buffer(bar)
    assert_equal([foo, baz, scratch, bar], Buffer.list)
    assert_equal(foo, Buffer.current)
    assert_equal(foo, Window.current.buffer)
    unbury_buffer
    assert_equal([bar, foo, baz, scratch], Buffer.list)
    assert_equal(bar, Buffer.current)
    assert_equal(bar, Window.current.buffer)
  end

  def test_kill_buffer
    foo = Buffer.new_buffer("foo")
    switch_to_buffer(foo)
    insert("foo")
    split_window

    push_keys("no\n")
    kill_buffer("foo")
    assert_equal(foo, Buffer.current)
    assert_equal(foo, Buffer["foo"])

    push_keys("yes\n")
    kill_buffer(foo)
    assert_not_equal(foo, Buffer.current)
    assert_equal(nil, Buffer["foo"])
    Window.list(include_echo_area: true).each do |window|
      assert_not_equal(foo, window.buffer)
    end

    buffers = Buffer.to_a
    buffers.each do |buffer|
      kill_buffer(buffer)
    end
    assert_equal("*scratch*", Buffer.current.name)
  end
end
