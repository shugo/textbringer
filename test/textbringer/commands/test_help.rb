require_relative "../../test_helper"

class TestHelp < Textbringer::TestCase
  def test_describe_bindings
    describe_bindings
    s = Buffer.current.to_s
    assert_match(/^a +self_insert/, s)
    assert_match(/^<backspace> +backward_delete_char/, s)
    assert_match(/^C-h +backward_delete_char/, s)
    assert_match(/^C-x RET f +set_buffer_file_encoding/, s)
  end
end
