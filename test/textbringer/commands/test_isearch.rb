require_relative "../../test_helper"

class TestIsearch < Textbringer::TestCase
  def test_isearch_forward
    buffer = Buffer.current
    buffer.insert(<<EOF)
　劉備は、船の商人らしい男を見かけてあわててそばへ寄って行った。
「茶を売って下さい、茶が欲しいんですが」
「え、茶だって？」
　洛陽《らくよう》の商人は、鷹揚《おうよう》に彼を振向いた。
「あいにくと、お前さんに頒《わ》けてやるような安茶は持たないよ。一葉《ひとは》いくらというような佳品しか船にはないよ」
「結構です。たくさんは要《い》りませんが」
「おまえ茶をのんだことがあるのかね。地方の衆が何か葉を煮てのんでいるが、あれは茶ではないよ」
「はい。その、ほんとの茶を頒《わ》けていただきたいのです」
　彼の声は、懸命だった。
　茶がいかに貴重か、高価か、また地方にもまだない物かは、彼もよくわきまえていた。
EOF
    buffer.beginning_of_buffer
    push_keys("茶\n")
    isearch_forward(recursive_edit: true)
    assert_equal(2, buffer.current_line)
    assert_equal(3, buffer.current_column)

    buffer.beginning_of_buffer
    push_keys("茶\C-s\n")
    isearch_forward(recursive_edit: true)
    assert_equal(2, buffer.current_line)
    assert_equal(12, buffer.current_column)

    buffer.beginning_of_buffer
    push_keys("茶が\n")
    isearch_forward(recursive_edit: true)
    assert_equal(2, buffer.current_line)
    assert_equal(13, buffer.current_column)

    buffer.beginning_of_buffer
    push_keys("茶が\C-h\n")
    isearch_forward(recursive_edit: true)
    assert_equal(2, buffer.current_line)
    assert_equal(3, buffer.current_column)

    buffer.beginning_of_buffer
    push_keys("茶を\C-s\C-s\n")
    isearch_forward(recursive_edit: true)
    assert_equal(8, buffer.current_line)
    assert_equal(14, buffer.current_column)

    buffer.beginning_of_buffer
    push_keys("茶を\C-g")
    isearch_forward(recursive_edit: true)
    assert_equal(true, buffer.beginning_of_buffer?)

    buffer.beginning_of_buffer
    push_keys("茶を\C-b")
    isearch_forward(recursive_edit: true)
    assert_equal(2, buffer.current_line)
    assert_equal(2, buffer.current_line)
  end

  def test_isearch_forward_case
    buffer = Buffer.current
    buffer.insert(<<EOF)
foo
bar
Foo
Bar
EOF
    buffer.beginning_of_buffer
    push_keys("bar\C-s\n")
    isearch_forward(recursive_edit: true)
    assert_equal(4, buffer.current_line)
    assert_equal(4, buffer.current_column)

    buffer.beginning_of_buffer
    push_keys("Bar\n")
    isearch_forward(recursive_edit: true)
    assert_equal(4, buffer.current_line)
    assert_equal(4, buffer.current_column)
  end

  def test_isearch_forward_repeat
    buffer = Buffer.current
    buffer.insert(<<EOF)
foo
bar
Foo
Bar
EOF
    buffer.beginning_of_buffer
    push_keys("foo\n")
    isearch_forward(recursive_edit: true)
    assert_equal(1, buffer.current_line)
    assert_equal(4, buffer.current_column)
    push_keys("\C-s\n")
    isearch_forward(recursive_edit: true)
    assert_equal(3, buffer.current_line)
    assert_equal(4, buffer.current_column)
  end

  def test_isearch_forward_fail
    buffer = Buffer.current
    buffer.insert(<<EOF)
foo
bar
Foo
Bar
EOF
    buffer.beginning_of_buffer
    push_keys("Fooo\n")
    isearch_forward(recursive_edit: true)
    assert_equal(3, buffer.current_line)
    assert_equal(4, buffer.current_column)
  end

  def test_isearch_backward
    buffer = Buffer.current
    buffer.insert(<<EOF)
　劉備は、船の商人らしい男を見かけてあわててそばへ寄って行った。
「茶を売って下さい、茶が欲しいんですが」
「え、茶だって？」
　洛陽《らくよう》の商人は、鷹揚《おうよう》に彼を振向いた。
「あいにくと、お前さんに頒《わ》けてやるような安茶は持たないよ。一葉《ひとは》いくらというような佳品しか船にはないよ」
「結構です。たくさんは要《い》りませんが」
「おまえ茶をのんだことがあるのかね。地方の衆が何か葉を煮てのんでいるが、あれは茶ではないよ」
「はい。その、ほんとの茶を頒《わ》けていただきたいのです」
　彼の声は、懸命だった。
　茶がいかに貴重か、高価か、また地方にもまだない物かは、彼もよくわきまえていた。
EOF
    buffer.end_of_buffer
    push_keys("茶を\C-r\n")
    isearch_backward(recursive_edit: true)
    assert_equal(7, buffer.current_line)
    assert_equal(5, buffer.current_column)
  end

  def test_isearch_exit
    isearch_forward
    isearch_exit
    assert_equal(nil, Controller.current.overriding_map)
  end

  def test_isearch_abort
    isearch_forward
    assert_raise(Quit) do
      isearch_abort
    end
    assert_equal(nil, Controller.current.overriding_map)
  end

  def test_isearch_yank_word_or_char
    buffer = Buffer.current
    buffer.insert(<<EOF)
foo
bar-baz
bar-quux
bar-baz
bar-quux
EOF
    buffer.beginning_of_buffer
    push_keys("bar\C-w\C-w\C-s\n")
    isearch_forward(recursive_edit: true)
    assert_equal(4, buffer.current_line)
    assert_equal(8, buffer.current_column)
  end

  def test_isearch_toggle_input_method
    buffer = Buffer.current
    buffer.insert(<<EOF)
foo一
foo二
EOF
    buffer.beginning_of_buffer
    push_keys("foo\C-\\\n")
    isearch_forward(recursive_edit: true)
    assert_instance_of(TCodeInputMethod, buffer.input_method)
  end

  def test_isearch_mark_set_and_cleanup
    buffer = Buffer.current
    buffer.insert(<<EOF)
foo
bar
baz
EOF
    buffer.beginning_of_buffer

    # isearch_mark should not be set initially
    assert_nil(buffer.isearch_mark)

    # Start isearch and search for "bar"
    push_keys("bar\n")
    isearch_forward(recursive_edit: true)

    # After search completes, isearch_mark should be cleaned up
    assert_nil(buffer.isearch_mark)
  end

  def test_isearch_mark_independent_from_visible_mark
    buffer = Buffer.current
    buffer.insert(<<EOF)
foo bar baz
quux bar quuz
EOF
    buffer.beginning_of_buffer

    # Set a region (visible_mark)
    set_mark_command
    buffer.forward_char(5)
    buffer.activate_mark
    assert_not_nil(buffer.visible_mark)
    visible_mark_pos = buffer.visible_mark.location

    # Now do an isearch - should not interfere with visible_mark
    push_keys("bar\n")
    isearch_forward(recursive_edit: true)

    # After isearch exits, visible_mark should still be there
    assert_not_nil(buffer.visible_mark)
    assert_equal(visible_mark_pos, buffer.visible_mark.location)

    # isearch_mark should be cleaned up
    assert_nil(buffer.isearch_mark)
  end
end
