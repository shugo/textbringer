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

    Clipboard.copy("かきくけこ\n")
    clipboard_yank
    assert_equal("あいうえお\nあいうえお\nかきくけこ\n", Buffer.current.to_s)
    assert_equal("かきくけこ\n", KILL_RING.current)
    assert_equal("あいうえお\n", KILL_RING.current(1))
    assert_equal(2, KILL_RING.size)
  end
end
