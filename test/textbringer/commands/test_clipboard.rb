require_relative "../../test_helper"

class TestClipboard < Textbringer::TestCase
  def test_clipboard_copy_region
    omit unless CLIPBOARD_AVAILABLE
    insert("あいうえお\n")
    set_mark_command
    insert("かきくけこ\n")
    clipboard_copy_region
    assert_equal("あいうえお\nかきくけこ\n", Buffer.current.to_s)
    assert_equal("かきくけこ\n", KILL_RING.current)
    assert_equal("かきくけこ\n", Clipboard.paste.encode("utf-8"))
  end

  def test_clipboard_kill_region
    omit unless CLIPBOARD_AVAILABLE
    insert("あいうえお\n")
    set_mark_command
    insert("かきくけこ\n")
    clipboard_kill_region
    assert_equal("あいうえお\n", Buffer.current.to_s)
    assert_equal("かきくけこ\n", KILL_RING.current)
    assert_equal("かきくけこ\n", Clipboard.paste.encode("utf-8"))
  end

  def test_clipboard_kill_line
    omit unless CLIPBOARD_AVAILABLE
    insert("あいうえお\n")
    insert("かきくけこ\n")
    beginning_of_buffer
    clipboard_kill_line
    assert_equal("\nかきくけこ\n", Buffer.current.to_s)
    assert_equal("あいうえお", KILL_RING.current)
    assert_equal("あいうえお", Clipboard.paste.encode("utf-8"))
  end

  def test_clipboard_kill_word
    omit unless CLIPBOARD_AVAILABLE
    insert("あいうえお\n")
    insert("かきくけこ\n")
    beginning_of_buffer
    clipboard_kill_word
    assert_equal("\nかきくけこ\n", Buffer.current.to_s)
    assert_equal("あいうえお", KILL_RING.current)
    assert_equal("あいうえお", Clipboard.paste.encode("utf-8"))
  end

  def test_clipboard_yank
    Clipboard.copy("あいうえお\n")
    clipboard_yank
    assert_equal("あいうえお\n", Buffer.current.to_s)
    assert_equal("あいうえお\n", KILL_RING.current)
    assert_equal(1, KILL_RING.size)

    clipboard_yank
    assert_equal("あいうえお\nあいうえお\n", Buffer.current.to_s)
    assert_equal("あいうえお\n", KILL_RING.current)
    assert_equal(1, KILL_RING.size)

    Clipboard.copy("かきくけこ\r\n")
    clipboard_yank
    assert_equal("あいうえお\nあいうえお\nかきくけこ\n", Buffer.current.to_s)
    assert_equal("かきくけこ\n", KILL_RING.current)
    assert_equal("あいうえお\n", KILL_RING.rotate(1))
    assert_equal(2, KILL_RING.size)

    Clipboard.copy("")
    clipboard_yank
    assert_equal("あいうえお\nあいうえお\nかきくけこ\nあいうえお\n",
                 Buffer.current.to_s)
    assert_equal("あいうえお\n", KILL_RING.current)
    assert_equal("かきくけこ\n", KILL_RING.rotate(1))
    assert_equal(2, KILL_RING.size)
  end

  def test_clipboard_yank_pop
    assert_raise(EditorError) do
      clipboard_yank_pop
    end
    insert("foo\n")
    insert("bar\n")
    insert("baz\n")
    beginning_of_buffer
    clipboard_kill_line
    next_line
    clipboard_kill_line
    next_line
    clipboard_kill_line
    clipboard_yank
    assert_equal("\n\nbaz\n", Buffer.current.to_s)
    Controller.current.last_command = :yank
    clipboard_yank_pop
    assert_equal("\n\nbar\n", Buffer.current.to_s)
    assert_equal("bar", Clipboard.paste.encode("utf-8"))
    clipboard_yank_pop
    assert_equal("\n\nfoo\n", Buffer.current.to_s)
    assert_equal("foo", Clipboard.paste.encode("utf-8"))
    clipboard_yank_pop
    assert_equal("\n\nbaz\n", Buffer.current.to_s)
    assert_equal("baz", Clipboard.paste.encode("utf-8"))
  end
end
