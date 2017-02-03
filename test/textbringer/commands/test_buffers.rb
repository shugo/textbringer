require_relative "../../test_helper"

class TestBuffers < Textbringer::TestCase
  def test_forward_char
    insert("hello world")
    beginning_of_buffer
    forward_char(3)
    assert_equal(3, Buffer.current.point)
  end

  def test_kill_region
    insert("foo")
    set_mark_command
    insert("bar")
    kill_region
    assert_equal("foo", Buffer.current.to_s)
  end

  def test_quoted_insert
    push_keys("\C-v")
    quoted_insert
    assert_equal("\C-v", Buffer.current.to_s)

    push_keys([Curses::KEY_LEFT])
    assert_raise(EditorError) do
      quoted_insert
    end
  end

  def test_yank_pop
    insert("foo\n")
    insert("bar\n")
    insert("baz\n")
    beginning_of_buffer
    kill_line
    next_line
    kill_line
    next_line
    kill_line
    yank
    assert_equal("\n\nbaz\n", Buffer.current.to_s)
    Controller.current.last_command = :yank
    yank_pop
    assert_equal("\n\nbar\n", Buffer.current.to_s)
    yank_pop
    assert_equal("\n\nfoo\n", Buffer.current.to_s)
    yank_pop
    assert_equal("\n\nbaz\n", Buffer.current.to_s)
  end
end
