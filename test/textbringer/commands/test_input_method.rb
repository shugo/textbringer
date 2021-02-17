require_relative "../../test_helper"

class TestInputMethodCommands < Textbringer::TestCase
  def test_toggle_input_method
    toggle_input_method
    assert_instance_of(TCodeInputMethod, Buffer.current.input_method)
    assert(Buffer.current.input_method.enabled?)
    toggle_input_method
    assert(!Buffer.current.input_method.enabled?)
    toggle_input_method("hiragana")
    assert_instance_of(HiraganaInputMethod, Buffer.current.input_method)
    assert(Buffer.current.input_method.enabled?)
    toggle_input_method("t_code")
    assert_instance_of(TCodeInputMethod, Buffer.current.input_method)
    assert(Buffer.current.input_method.enabled?)
    Controller.current.current_prefix_arg = [4]
    push_keys("hira\t\n")
    toggle_input_method
    assert_instance_of(HiraganaInputMethod, Buffer.current.input_method)
    assert(Buffer.current.input_method.enabled?)
  end

  def test_read_input_method_name
    push_keys("\n")
    s = read_input_method_name("Input method: ")
    assert_equal("t_code", s)

    push_keys("hira\t\n")
    s = read_input_method_name("Input method: ")
    assert_equal("hiragana", s)

    push_keys("katakana\t\n")
    s = read_input_method_name("Input method: ")
    assert_equal("katakana", s)
  end
end

