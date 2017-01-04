require "test/unit"
require "text_bringer/buffer"

class TestBuffer < Test::Unit::TestCase
  include TextBringer

  def test_insert
    buffer = Buffer.new
    buffer.insert("abc")
    buffer.beginning_of_buffer
    buffer.insert("123")
    assert_equal("123abc", buffer.to_s)
    s = "x" * (Buffer::GAP_SIZE + 1)
    buffer.insert(s)
    assert_equal("123#{s}abc", buffer.to_s)
  end

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
    buffer.insert("Hello world\n")
    buffer.insert("I'm shugo\n")
    buffer.beginning_of_buffer
    buffer.delete_char("Hello".size)
    buffer.insert("Goodbye")
    assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm shugo
EOF
    buffer.end_of_buffer
    buffer.backward_char
    buffer.delete_char(-"shugo".size)
    buffer.insert("tired")
    assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
EOF
    buffer.end_of_buffer
    buffer.insert("How are you?\n")
    assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
How are you?
EOF
    buffer.backward_char("How are you?\n".size)
    buffer.delete_char(-"I'm tired\n".size)
    assert_equal(<<EOF, buffer.to_s)
Goodbye world
How are you?
EOF
    buffer.beginning_of_buffer
    buffer.delete_char("Goodbye".size)
    buffer.insert("Hello")
    assert_equal(<<EOF, buffer.to_s)
Hello world
How are you?
EOF
    buffer.end_of_buffer
    buffer.insert("I'm fine\n")
    assert_equal(<<EOF, buffer.to_s)
Hello world
How are you?
I'm fine
EOF
  end

  def test_to_s
    buffer = Buffer.new
    buffer.insert("あいうえお")
    s = buffer.to_s
    assert_equal("あいうえお", s)
  end

  def test_substring
    buffer = Buffer.new
    buffer.insert("12345\n12345\n")
    buffer.backward_char("12345\n".size)
    buffer.insert("12345\n")
    assert_equal("1", buffer.substring(buffer.point, buffer.point + 1))
    assert_equal("123", buffer.substring(buffer.point, buffer.point + 3))
  end

  def test_char_after
    buffer = Buffer.new
    buffer.insert("12345\nあいうえお\n")
    buffer.beginning_of_buffer
    assert_equal("1", buffer.char_after)
    buffer.next_line
    assert_equal("あ", buffer.char_after)
    buffer.forward_char
    assert_equal("い", buffer.char_after)
  end

  def test_next_line
    buffer = Buffer.new
    buffer.insert(<<EOF)
hello world
0123456789

hello world
0123456789
EOF
    buffer.beginning_of_buffer
    buffer.forward_char(3)
    assert_equal(3, buffer.point)
    buffer.next_line
    assert_equal(15, buffer.point)
    buffer.next_line
    assert_equal(23, buffer.point)
    buffer.next_line
    assert_equal(27, buffer.point)
    buffer.backward_char
    buffer.next_line
    assert_equal(38, buffer.point)
  end

  def test_next_line_multibyte
    buffer = Buffer.new
    buffer.insert(<<EOF)
0123456789
あいうえお
aかきくけこ
EOF
    buffer.beginning_of_buffer
    buffer.forward_char(4)
    assert_equal(4, buffer.point)
    buffer.next_line
    assert_equal(17, buffer.point)
    buffer.next_line
    assert_equal(34, buffer.point)
  end

  def test_previous_line
    buffer = Buffer.new
    buffer.insert(<<EOF)
hello world
0123456789

hello world
0123456789
EOF
    buffer.previous_line
    buffer.forward_char(3)
    assert_equal(39, buffer.point)
    buffer.previous_line
    assert_equal(27, buffer.point)
    buffer.previous_line
    assert_equal(23, buffer.point)
    buffer.previous_line
    assert_equal(15, buffer.point)
    buffer.backward_char
    buffer.previous_line
    assert_equal(2, buffer.point)
  end

  def test_beginning_of_line
    buffer = Buffer.new
    buffer.insert(<<EOF)
hello world
0123456789
EOF
    buffer.beginning_of_buffer
    buffer.forward_char(3)
    buffer.beginning_of_line
    assert_equal(0, buffer.point)
    buffer.next_line
    buffer.forward_char(3)
    buffer.beginning_of_line
    assert_equal(12, buffer.point)
  end

  def test_end_of_line
    buffer = Buffer.new
    buffer.insert(<<EOF.chomp)
hello world
0123456789
EOF
    buffer.beginning_of_buffer
    buffer.forward_char(3)
    buffer.end_of_line
    assert_equal(11, buffer.point)
    buffer.forward_char(3)
    buffer.end_of_line
    assert_equal(22, buffer.point)
  end
end
