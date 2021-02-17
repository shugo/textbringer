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
  end
end
