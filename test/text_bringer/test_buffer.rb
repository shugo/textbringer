require "test/unit"
require "text_bringer/buffer"

class TestBuffer < Test::Unit::TestCase
  include TextBringer

  def test_forward_char
    buffer = Buffer.new
    buffer.insert("abc")
    buffer.beginning_of_buffer
    buffer.forward_char
    assert_equal(1, buffer.point)
    buffer.forward_char(2)
    assert_equal(3, buffer.point)
    assert_raise(RangeError) do
      buffer.forward_char
    end
    buffer.forward_char(-1)
    assert_equal(2, buffer.point)
    buffer.forward_char(-2)
    assert_equal(0, buffer.point)
    assert_raise(RangeError) do
      buffer.forward_char(-1)
    end
  end

  def test_delete_char_forward
    buffer = Buffer.new
    buffer.insert("abc")
    buffer.backward_char(1)
    buffer.delete_char
    assert_equal("ab", buffer.to_s)
    assert_equal(2, buffer.point)
  end

  def test_delete_char_backward
    buffer = Buffer.new
    buffer.insert("abc")
    buffer.backward_char(1)
    buffer.delete_char(-2)
    assert_equal("c", buffer.to_s)
    assert_equal(0, buffer.point)
  end

  def test_delete_char_at_eob
    buffer = Buffer.new
    buffer.insert("abc")
    assert_raise(RangeError) do
      buffer.delete_char
    end
    assert_equal("abc", buffer.to_s)
    assert_equal(3, buffer.point)
  end

  def test_delete_char_over_eob
    buffer = Buffer.new
    buffer.insert("abc")
    buffer.backward_char(2)
    assert_raise(RangeError) do
      buffer.delete_char(3)
    end
    assert_equal("abc", buffer.to_s)
    assert_equal(1, buffer.point)
  end

  def test_delete_char_at_bob
    buffer = Buffer.new
    buffer.insert("abc")
    buffer.beginning_of_buffer
    assert_raise(RangeError) do
      buffer.delete_char(-1)
    end
    assert_equal("abc", buffer.to_s)
    assert_equal(0, buffer.point)
  end

  def test_delete_char_over_bob
    buffer = Buffer.new
    buffer.insert("abc")
    buffer.backward_char(1)
    assert_raise(RangeError) do
      buffer.delete_char(-3)
    end
    assert_equal("abc", buffer.to_s)
    assert_equal(2, buffer.point)
  end

  def test_editing
    buffer = Buffer.new
    buffer.insert("hello world\n")
    buffer.insert("I'm shugo\n")
    buffer.beginning_of_buffer
    buffer.delete_char(5)
    buffer.insert("goodbye")
    buffer.end_of_buffer
    buffer.backward_char
    buffer.delete_char(-5)
    buffer.insert("tired")
    assert_equal(<<EOF, buffer.to_s)
goodbye world
I'm tired
EOF
  end
end
