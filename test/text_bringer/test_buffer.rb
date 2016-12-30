require "test/unit"
require "text_bringer/buffer"

class TestBuffer < Test::Unit::TestCase
  include TextBringer

  def test_delete_char
    buffer = Buffer.new
    buffer.insert("abc")
    buffer.backward_char(2)
    buffer.delete_char
    assert_equal("ac", buffer.to_s)
  end
end
