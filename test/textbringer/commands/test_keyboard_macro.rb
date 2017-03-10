require_relative "../../test_helper"

class TestKeyboardMacro < Textbringer::TestCase
  def test_keyboard_macro
    push_keys "\C-x(hello world\n\C-x)\C-xee\C-u2\C-xe"
    recursive_edit
    assert_equal("hello world\n" * 5, Buffer.current.to_s)
  end

  def test_start_keyboard_macro_twice
    start_keyboard_macro
    assert_raise(EditorError) do
      start_keyboard_macro
    end
  end

  def test_end_keyboard_macro_not_recording
    assert_raise(EditorError) do
      end_keyboard_macro
    end
  end

  def test_end_keyboard_macro_empty
    start_keyboard_macro
    assert_raise(EditorError) do
      end_keyboard_macro
    end
  end

  def test_call_last_keyboard_macro_undefined
    assert_raise(EditorError) do
      call_last_keyboard_macro
    end
  end

  def test_name_last_keyboard_macro
    push_keys "\C-x(foo\n\C-x)"
    recursive_edit
    name_last_keyboard_macro("macro_foo")
    push_keys "\C-x(bar\n\C-x)"
    recursive_edit
    macro_foo(2)
    assert_equal("foo\nbar\nfoo\nfoo\n", Buffer.current.to_s)
  end

  def test_insert_keyboard_macro
    push_keys "\C-x(bar\r\C-x)"
    recursive_edit
    name_last_keyboard_macro("macro_bar")
    insert_keyboard_macro("macro_bar")
    assert_equal(<<'EOF', Buffer.current.to_s)
bar
define_command(:macro_bar) do |n = number_prefix_arg|
  execute_keyboard_macro(["b","a","r","\r"], n)
end
EOF
  end
end
