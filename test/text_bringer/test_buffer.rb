require "test/unit"
require "text_bringer/buffer"

class TestBuffer < Test::Unit::TestCase
  include TextBringer

  def test_delete_char_forward
    buffer = Buffer.new
    buffer.insert("abc")
    buffer.backward_char(2)
    buffer.delete_char
    assert_equal("ac", buffer.to_s)
  end

  def test_delete_char_backward
    buffer = Buffer.new
    buffer.insert("abc")
    buffer.backward_char(2)
    buffer.delete_char(-1)
    assert_equal("bc", buffer.to_s)
  end
end
