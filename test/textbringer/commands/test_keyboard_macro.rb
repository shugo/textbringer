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
end
