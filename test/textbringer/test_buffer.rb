require "test/unit"
require "tempfile"
require "textbringer/buffer"

class TestBuffer < Test::Unit::TestCase
  include Textbringer

  def test_insert
    buffer = Buffer.new("abc")
    buffer.insert("123")
    assert_equal("123abc", buffer.to_s)
    s = "x" * (Buffer::GAP_SIZE + 1)
    buffer.insert(s)
    assert_equal("123#{s}abc", buffer.to_s)
  end

  def test_newline
    buffer = Buffer.new("abc")
    buffer.end_of_buffer
    buffer.newline
    assert_equal("abc\n", buffer.to_s)
    buffer.insert("   foo")
    buffer.newline
    assert_equal("abc\n   foo\n   ", buffer.to_s)
    buffer.newline
    assert_equal("abc\n   foo\n\n   ", buffer.to_s)
    buffer.insert("\n")
    buffer.backward_char
    buffer.newline
    assert_equal("abc\n   foo\n\n\n   \n", buffer.to_s)
  end

  def test_delete_char
    buffer = Buffer.new("123abcあいうえお")
    buffer.forward_char(3)
    buffer.delete_char
    assert_equal("123bcあいうえお", buffer.to_s)
    buffer.delete_char(2)
    assert_equal("123あいうえお", buffer.to_s)
    buffer.delete_char
    assert_equal("123いうえお", buffer.to_s)
    buffer.delete_char(-2)
    assert_equal("1いうえお", buffer.to_s)
    buffer.forward_char(3)
    buffer.delete_char(-2)
    assert_equal("1いお", buffer.to_s)
  end

  def test_forward_char
    buffer = Buffer.new("abc")
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
    buffer = Buffer.new("abc")
    buffer.end_of_buffer
    buffer.backward_char(1)
    buffer.delete_char
    assert_equal("ab", buffer.to_s)
    assert_equal(2, buffer.point)
  end

  def test_delete_char_backward
    buffer = Buffer.new("abc")
    buffer.end_of_buffer
    buffer.backward_char(1)
    buffer.delete_char(-2)
    assert_equal("c", buffer.to_s)
    assert_equal(0, buffer.point)
  end

  def test_delete_char_at_eob
    buffer = Buffer.new("abc")
    buffer.end_of_buffer
    assert_raise(RangeError) do
      buffer.delete_char
    end
    assert_equal("abc", buffer.to_s)
    assert_equal(3, buffer.point)
  end

  def test_delete_char_over_eob
    buffer = Buffer.new("abc")
    buffer.forward_char(1)
    assert_raise(RangeError) do
      buffer.delete_char(3)
    end
    assert_equal("abc", buffer.to_s)
    assert_equal(1, buffer.point)
  end

  def test_delete_char_at_bob
    buffer = Buffer.new("abc")
    assert_raise(RangeError) do
      buffer.delete_char(-1)
    end
    assert_equal("abc", buffer.to_s)
    assert_equal(0, buffer.point)
  end

  def test_delete_char_over_bob
    buffer = Buffer.new("abc")
    buffer.end_of_buffer
    buffer.backward_char(1)
    assert_raise(RangeError) do
      buffer.delete_char(-3)
    end
    assert_equal("abc", buffer.to_s)
    assert_equal(2, buffer.point)
  end

  def test_editing
    buffer = Buffer.new(<<EOF)
Hello world
I'm shugo
EOF
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
    buffer = Buffer.new("あいうえお")
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
    buffer = Buffer.new(<<EOF)
hello world
0123456789

hello world
0123456789
EOF
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
    buffer = Buffer.new(<<EOF)
0123456789
あいうえお
aかきくけこ
EOF
    buffer.forward_char(4)
    assert_equal(4, buffer.point)
    buffer.next_line
    assert_equal(17, buffer.point)
    buffer.next_line
    assert_equal(34, buffer.point)
  end

  def test_previous_line
    buffer = Buffer.new(<<EOF)
hello world
0123456789

hello world
0123456789
EOF
    buffer.end_of_buffer
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
    buffer = Buffer.new(<<EOF)
hello world
0123456789
EOF
    buffer.forward_char(3)
    buffer.beginning_of_line
    assert_equal(0, buffer.point)
    buffer.next_line
    buffer.forward_char(3)
    buffer.beginning_of_line
    assert_equal(12, buffer.point)
  end

  def test_end_of_line
    buffer = Buffer.new(<<EOF.chomp)
hello world
0123456789
EOF
    buffer.forward_char(3)
    buffer.end_of_line
    assert_equal(11, buffer.point)
    buffer.forward_char(3)
    buffer.end_of_line
    assert_equal(22, buffer.point)
  end

  def test_copy_region
    buffer = Buffer.new(<<EOF)
0123456789
abcdefg
あいうえお
かきくけこ
EOF
    buffer.next_line
    buffer.set_mark
    buffer.next_line
    buffer.copy_region
    assert_equal("abcdefg\n", KILL_RING.last)
    assert_equal(<<EOF, buffer.to_s)
0123456789
abcdefg
あいうえお
かきくけこ
EOF
    buffer.next_line
    buffer.copy_region
    assert_equal("abcdefg\nあいうえお\n", KILL_RING.last)
    assert_equal(<<EOF, buffer.to_s)
0123456789
abcdefg
あいうえお
かきくけこ
EOF
  end

  def test_kill_region
    buffer = Buffer.new(<<EOF)
0123456789
abcdefg
あいうえお
かきくけこ
EOF
    buffer.next_line
    buffer.set_mark
    buffer.next_line
    buffer.kill_region
    assert_equal("abcdefg\n", KILL_RING.last)
    assert_equal(<<EOF, buffer.to_s)
0123456789
あいうえお
かきくけこ
EOF
    buffer.next_line
    buffer.kill_region
    assert_equal("あいうえお\n", KILL_RING.last)
    assert_equal(<<EOF, buffer.to_s)
0123456789
かきくけこ
EOF
  end

  def test_kill_line
    buffer = Buffer.new(<<EOF)
0123456789
abcdefg
あいうえお
かきくけこ
EOF
    buffer.next_line
    buffer.kill_line
    assert_equal("abcdefg", KILL_RING.last)
    assert_equal(<<EOF, buffer.to_s)
0123456789

あいうえお
かきくけこ
EOF
    buffer.kill_line
    assert_equal("\n", KILL_RING.last)
    assert_equal(<<EOF, buffer.to_s)
0123456789
あいうえお
かきくけこ
EOF
    buffer.kill_line
    assert_equal("あいうえお", KILL_RING.last)
    assert_equal(<<EOF, buffer.to_s)
0123456789

かきくけこ
EOF
  end

  def test_save_ascii_only
    Tempfile.create do |f|
      f.print(<<EOF)
hello world
EOF
      f.close
      buffer = Buffer.open(f.path)
      assert_equal(Encoding::UTF_8, buffer.file_encoding)
      assert_equal("hello world\n", buffer.to_s)
      buffer.end_of_buffer
      buffer.insert("goodbye\n")
      buffer.save
      assert_equal(<<EOF, File.read(f.path))
hello world
goodbye
EOF
    end
  end

  def test_save_utf8
    Tempfile.create do |f|
      f.print(<<EOF)
こんにちは
EOF
      f.close
      buffer = Buffer.open(f.path)
      assert_equal(Encoding::UTF_8, buffer.file_encoding)
      assert_equal("こんにちは\n", buffer.to_s)
      buffer.end_of_buffer
      buffer.insert("さようなら\n")
      buffer.save
      assert_equal(<<EOF, File.read(f.path))
こんにちは
さようなら
EOF
    end
  end

  def test_save_euc_jp
    Tempfile.create do |f|
      f.print(<<EOF.encode(Encoding::EUC_JP))
こんにちは
EOF
      f.close
      buffer = Buffer.open(f.path)
      assert_equal(Encoding::EUC_JP, buffer.file_encoding)
      assert_equal("こんにちは\n", buffer.to_s)
      buffer.end_of_buffer
      buffer.insert("さようなら\n")
      buffer.save
      assert_equal(<<EOF.encode(Encoding::EUC_JP), File.read(f.path, encoding: Encoding::EUC_JP))
こんにちは
さようなら
EOF
    end
  end

  def test_save_windows31j
    Tempfile.create do |f|
      f.print(<<EOF.encode(Encoding::Windows_31J))
こんにちは
EOF
      f.close
      buffer = Buffer.open(f.path)
      assert_equal(Encoding::Windows_31J, buffer.file_encoding)
      assert_equal("こんにちは\n", buffer.to_s)
      buffer.end_of_buffer
      buffer.insert("さようなら\n")
      buffer.save
      assert_equal(<<EOF.encode(Encoding::Windows_31J), File.read(f.path, encoding: Encoding::Windows_31J))
こんにちは
さようなら
EOF
    end
  end

  def test_save_dos
    Tempfile.create do |f|
      f.print(<<EOF.gsub(/\n/, "\r\n").encode(Encoding::Windows_31J))
こんにちは
EOF
      f.close
      buffer = Buffer.open(f.path)
      assert_equal(Encoding::Windows_31J, buffer.file_encoding)
      assert_equal("こんにちは\n", buffer.to_s)
      buffer.end_of_buffer
      buffer.insert("さようなら\n")
      buffer.save
      assert_equal(<<EOF.gsub(/\n/, "\r\n").encode(Encoding::Windows_31J), File.read(f.path, encoding: Encoding::Windows_31J))
こんにちは
さようなら
EOF
    end
  end

  def test_save_mac
    Tempfile.create do |f|
      f.print(<<EOF.gsub(/\n/, "\r").encode(Encoding::Windows_31J))
こんにちは
EOF
      f.close
      buffer = Buffer.open(f.path)
      assert_equal(Encoding::Windows_31J, buffer.file_encoding)
      assert_equal("こんにちは\n", buffer.to_s)
      buffer.end_of_buffer
      buffer.insert("さようなら\n")
      buffer.save
      assert_equal(<<EOF.gsub(/\n/, "\r").encode(Encoding::Windows_31J), File.read(f.path, encoding: Encoding::Windows_31J))
こんにちは
さようなら
EOF
    end
  end

  def test_file_format
    buffer = Buffer.new("foo")
    assert_equal(:unix, buffer.file_format)
    assert_equal("foo", buffer.to_s)

    buffer = Buffer.new("foo\nbar\r\n")
    assert_equal(:unix, buffer.file_format)
    assert_equal("foo\nbar\r\n", buffer.to_s)

    buffer = Buffer.new("foo\r\nbar\r\n")
    assert_equal(:dos, buffer.file_format)
    assert_equal("foo\nbar\n", buffer.to_s)

    buffer = Buffer.new("foo\rbar\r")
    assert_equal(:mac, buffer.file_format)
    assert_equal("foo\nbar\n", buffer.to_s)
  end
end
