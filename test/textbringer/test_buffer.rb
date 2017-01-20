require_relative "../test_helper"
require "tempfile"
require "tmpdir"

class TestBuffer < Test::Unit::TestCase
  include Textbringer

  def teardown
    Buffer.kill_em_all
    KILL_RING.clear
  end

  def test_insert
    buffer = Buffer.new("abc")
    buffer.insert("123")
    assert_equal("123abc", buffer.to_s)
    assert_equal(3, buffer.point)
    assert_equal(1, buffer.current_line)
    assert_equal(4, buffer.current_column)
    assert_equal(true, buffer.gap_filled_with_nul?)
    s = "x" * (Buffer::GAP_SIZE + 1)
    buffer.insert(s)
    assert_equal("123#{s}abc", buffer.to_s)
    assert_equal(Buffer::GAP_SIZE + 4, buffer.point)
    assert_equal(1, buffer.current_line)
    assert_equal(Buffer::GAP_SIZE + 5, buffer.current_column)
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.insert("\nfoo")
    assert_equal(2, buffer.current_line)
    assert_equal(4, buffer.current_column)
  end

  def test_newline
    buffer = Buffer.new("abc")
    buffer.end_of_buffer
    buffer.newline
    assert_equal("abc\n", buffer.to_s)
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.insert("   foo")
    buffer.newline
    assert_equal("abc\n   foo\n   ", buffer.to_s)
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.newline
    assert_equal("abc\n   foo\n\n   ", buffer.to_s)
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.insert("\n")
    buffer.backward_char
    buffer.newline
    assert_equal("abc\n   foo\n\n\n   \n", buffer.to_s)
    assert_equal(true, buffer.gap_filled_with_nul?)
  end

  def test_delete_char
    buffer = Buffer.new("123abcあいうえお")
    buffer.forward_char(3)
    buffer.delete_char
    assert_equal("123bcあいうえお", buffer.to_s)
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.delete_char(2)
    assert_equal("123あいうえお", buffer.to_s)
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.delete_char
    assert_equal("123いうえお", buffer.to_s)
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.delete_char(-2)
    assert_equal("1いうえお", buffer.to_s)
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.forward_char(3)
    buffer.delete_char(-2)
    assert_equal("1いお", buffer.to_s)
    assert_equal(true, buffer.gap_filled_with_nul?)

    buffer = Buffer.new("abcdefghijklmnopqrstuvwxyz")
    buffer.forward_char(16)
    mark = buffer.new_mark
    assert_equal(16, mark.location)
    buffer.backward_char(5)
    buffer.delete_char(10)
    assert_equal(11, mark.location)

    buffer = Buffer.new("abcdefghijklmnopqrstuvwxyz")
    buffer.forward_char(16)
    mark = buffer.new_mark
    assert_equal(16, mark.location)
    buffer.forward_char(5)
    buffer.delete_char(-10)
    assert_equal(11, mark.location)
  end

  def test_forward_char
    buffer = Buffer.new("abc")
    assert_equal(1, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.forward_char
    assert_equal(1, buffer.point)
    assert_equal(1, buffer.current_line)
    assert_equal(2, buffer.current_column)
    buffer.forward_char(2)
    assert_equal(3, buffer.point)
    assert_equal(1, buffer.current_line)
    assert_equal(4, buffer.current_column)
    assert_raise(RangeError) do
      buffer.forward_char
    end
    buffer.forward_char(-1)
    assert_equal(2, buffer.point)
    assert_equal(1, buffer.current_line)
    assert_equal(3, buffer.current_column)
    buffer.forward_char(-2)
    assert_equal(0, buffer.point)
    assert_equal(1, buffer.current_line)
    assert_equal(1, buffer.current_column)
    assert_raise(RangeError) do
      buffer.forward_char(-1)
    end
    buffer = Buffer.new
    buffer.insert("\n")
    buffer.forward_char(-1)
    assert_equal(1, buffer.current_line)
    assert_equal(1, buffer.current_column)
  end

  def test_delete_char_forward
    buffer = Buffer.new("abc")
    buffer.end_of_buffer
    buffer.backward_char(1)
    buffer.delete_char
    assert_equal("ab", buffer.to_s)
    assert_equal(2, buffer.point)
    assert_equal(true, buffer.gap_filled_with_nul?)
  end

  def test_delete_char_backward
    buffer = Buffer.new("abc")
    buffer.end_of_buffer
    buffer.backward_char(1)
    buffer.delete_char(-2)
    assert_equal("c", buffer.to_s)
    assert_equal(0, buffer.point)
    assert_equal(true, buffer.gap_filled_with_nul?)
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

  def test_forward_word
    buffer = Buffer.new(<<EOF)
hello world
good_bye
EOF
    buffer.forward_word
    assert_equal(5, buffer.point)
    buffer.forward_word
    assert_equal(11, buffer.point)
    buffer.forward_word
    assert_equal(16, buffer.point)
    buffer.forward_word
    assert_equal(20, buffer.point)
    buffer.beginning_of_buffer
    buffer.forward_word(2)
    assert_equal(11, buffer.point)
  end

  def test_backward_word
    buffer = Buffer.new(<<EOF)
hello world
good_bye


EOF
    buffer.end_of_buffer
    buffer.backward_word
    assert_equal(17, buffer.point)
    buffer.backward_word
    assert_equal(12, buffer.point)
    buffer.backward_word
    assert_equal(6, buffer.point)
    buffer.backward_word
    assert_equal(0, buffer.point)
    buffer.end_of_buffer
    buffer.backward_word(2)
    assert_equal(12, buffer.point)
  end

  def test_forward_line
    buffer = Buffer.new(<<EOF.chop)
hello world
0123456789

hello world
0123456789
xxx
EOF
    buffer.forward_char(3)
    assert_equal(3, buffer.point)
    buffer.forward_line
    assert_equal(2, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.forward_char(4)
    buffer.forward_line(2)
    assert_equal(4, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.forward_line(2)
    assert_equal(6, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.forward_line
    assert_equal(true, buffer.end_of_buffer?)
  end

  def test_backward_line
    buffer = Buffer.new(<<EOF)
hello world
0123456789

hello world
0123456789
EOF
    buffer.end_of_buffer
    buffer.backward_line
    assert_equal(5, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.forward_char(4)
    buffer.backward_line
    assert_equal(4, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.forward_char(3)
    buffer.backward_line(2)
    assert_equal(2, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.backward_line(2)
    assert_equal(1, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.backward_line
    assert_equal(true, buffer.beginning_of_buffer?)
    buffer.forward_char(3)
    buffer.backward_line
    assert_equal(true, buffer.beginning_of_buffer?)
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
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.end_of_buffer
    buffer.backward_char
    buffer.delete_char(-"shugo".size)
    buffer.insert("tired")
    assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.end_of_buffer
    buffer.insert("How are you?\n")
    assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
How are you?
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.backward_char("How are you?\n".size)
    buffer.delete_char(-"I'm tired\n".size)
    assert_equal(<<EOF, buffer.to_s)
Goodbye world
How are you?
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.beginning_of_buffer
    buffer.delete_char("Goodbye".size)
    buffer.insert("Hello")
    assert_equal(<<EOF, buffer.to_s)
Hello world
How are you?
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.end_of_buffer
    buffer.insert("I'm fine\n")
    assert_equal(<<EOF, buffer.to_s)
Hello world
How are you?
I'm fine
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)
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
    buffer.end_of_buffer
    assert_equal(nil, buffer.char_after)
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
    assert_raise(EditorError) do
      buffer.copy_region
    end
    buffer.next_line
    buffer.set_mark
    buffer.next_line
    buffer.copy_region
    assert_equal("abcdefg\n", KILL_RING.current)
    assert_equal(<<EOF, buffer.to_s)
0123456789
abcdefg
あいうえお
かきくけこ
EOF
    buffer.next_line
    buffer.copy_region
    assert_equal("abcdefg\nあいうえお\n", KILL_RING.current)
    assert_equal(<<EOF, buffer.to_s)
0123456789
abcdefg
あいうえお
かきくけこ
EOF
    buffer.copy_region(3, 7, true)
    assert_equal("abcdefg\nあいうえお\n3456", KILL_RING.current)
  end

  def test_delete_region
    buffer = Buffer.new("foobar")
    buffer.end_of_buffer
    mark = buffer.new_mark
    buffer.backward_char(3)
    mark2 = buffer.new_mark
    buffer.backward_char
    buffer.delete_region(1, 4)
    assert_equal(1, buffer.point)
    assert_equal(3, mark.location)
    assert_equal(1, mark2.location)
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
    assert_equal(2, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.next_line
    assert_equal(3, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.kill_region
    assert_equal(2, buffer.current_line)
    assert_equal(1, buffer.current_column)
    assert_equal("abcdefg\n", KILL_RING.current)
    assert_equal(<<EOF, buffer.to_s)
0123456789
あいうえお
かきくけこ
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.next_line
    buffer.kill_region
    assert_equal("あいうえお\n", KILL_RING.current)
    assert_equal(<<EOF, buffer.to_s)
0123456789
かきくけこ
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)
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
    assert_equal("abcdefg", KILL_RING.current)
    assert_equal(<<EOF, buffer.to_s)
0123456789

あいうえお
かきくけこ
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.kill_line
    assert_equal("\n", KILL_RING.current)
    assert_equal(<<EOF, buffer.to_s)
0123456789
あいうえお
かきくけこ
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.kill_line
    assert_equal("あいうえお", KILL_RING.current)
    assert_equal(<<EOF, buffer.to_s)
0123456789

かきくけこ
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)

    buffer.end_of_buffer
    assert_raise(RangeError) do
      buffer.kill_line
    end
  end

  def test_kill_word
    buffer = Buffer.new(<<EOF)
hello world
あいうえお
EOF
    buffer.kill_word
    assert_equal("hello", KILL_RING.current)
    assert_equal(<<EOF, buffer.to_s)
 world
あいうえお
EOF
    assert_equal(true, buffer.gap_filled_with_nul?)
    buffer.end_of_line
    buffer.kill_word
    assert_equal("\nあいうえお", KILL_RING.current)
    assert_equal(" world\n", buffer.to_s)
    assert_equal(true, buffer.gap_filled_with_nul?)

    buffer.end_of_buffer
    assert_raise(RangeError) do
      buffer.kill_word
    end
  end

  def test_save_ascii_only
    Tempfile.create("test_buffer") do |f|
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
    Tempfile.create("test_buffer") do |f|
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
    Tempfile.create("test_buffer") do |f|
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
    Tempfile.create("test_buffer") do |f|
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

  def test_save_iso2022jp
    old_detect_encoding_proc = Buffer.detect_encoding_proc
    Buffer.detect_encoding_proc = Buffer::NKF_DETECT_ENCODING
    begin
      Tempfile.create("test_buffer") do |f|
        f.print(<<EOF.encode(Encoding::ISO_2022_JP))
こんにちは
EOF
        f.close
        buffer = Buffer.open(f.path)
        assert_equal(Encoding::ISO_2022_JP, buffer.file_encoding)
        assert_equal("こんにちは\n", buffer.to_s)
        buffer.end_of_buffer
        buffer.insert("さようなら\n")
        buffer.save
        assert_equal(<<EOF.encode(Encoding::ISO_2022_JP), File.read(f.path, encoding: Encoding::ISO_2022_JP, binmode: true))
こんにちは
さようなら
EOF
      end
    ensure
      Buffer.detect_encoding_proc = old_detect_encoding_proc
    end
  end

  def test_save_binary
    Tempfile.create("test_buffer") do |f|
      data = (0..255).to_a.pack("C*")
      f.print(data)
      f.close
      buffer = Buffer.open(f.path)
      assert_equal(Encoding::ASCII_8BIT, buffer.file_encoding)
      assert_equal(data, buffer.to_s)
      buffer.end_of_buffer
      buffer.insert("\de\ad\be\ef")
      buffer.save
      assert_equal(data + "\de\ad\be\ef", File.read(f.path, binmode: true))
    end
  end

  def test_save_binary_with_nkf
    old_detect_encoding_proc = Buffer.detect_encoding_proc
    Buffer.detect_encoding_proc = Buffer::NKF_DETECT_ENCODING
    begin
      test_save_binary
    ensure
      Buffer.detect_encoding_proc = old_detect_encoding_proc
    end
  end

  def test_save_dos
    Tempfile.create("test_buffer") do |f|
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
    Tempfile.create("test_buffer") do |f|
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

  def test_save_no_file_name
    buffer = Buffer.new
    assert_raise(EditorError) do
      buffer.save
    end
  end

  def test_save_as
    Tempfile.create("test_buffer") do |f|
      f.close
      buffer = Buffer.new("hello world")
      buffer.save(f.path)
      assert_equal("hello world", File.read(f.path))
      assert_equal(f.path, buffer.file_name)
      assert_equal(File.basename(f.path), buffer.name)
    end
  end

  def test_save_as_dir
    Dir.mktmpdir do |dir|
      buffer = Buffer.new("hello world")
      assert_raise(Errno::EISDIR) do
        buffer.save(dir)
      end
      buffer.name = "foo"
      buffer.save(dir)
      assert_equal("hello world", File.read(buffer.file_name))
      assert_equal(File.expand_path("foo", dir), buffer.file_name)
      assert_equal("foo", buffer.name)
    end
  end

  def test_save_as_fail
    Tempfile.create("test_buffer") do |f|
      f.close
      File.chmod(0400, f.path)
      buffer = Buffer.new("hello world", name: "foo")
      assert_raise(Errno::EACCES) do
        buffer.save(f.path)
      end
      assert_equal("", File.read(f.path))
      assert_equal(nil, buffer.file_name)
      assert_equal("foo", buffer.name)
    end
  end

  def test_file_modified?
    buffer = Buffer.new
    assert_equal(false, buffer.file_modified?)
    Tempfile.create("test_buffer") do |f|
      f.print("foo")
      f.close
      buffer = Buffer.open(f.path)
      assert_equal(false, buffer.file_modified?)
      sleep(0.01)
      File.write(f.path, "bar")
      assert_equal(true, buffer.file_modified?)
      buffer.save
      assert_equal(false, buffer.file_modified?)
      assert_equal("foo", File.read(f.path))
      sleep(0.01)
      File.write(f.path, "bar")
      assert_equal(true, buffer.file_modified?)
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

    buffer = Buffer.new
    assert_equal(:unix, buffer.file_format)
    buffer.file_format = :dos
    assert_equal(:dos, buffer.file_format)
    buffer.file_format = :mac
    assert_equal(:mac, buffer.file_format)
    buffer.file_format = :unix
    assert_equal(:unix, buffer.file_format)
    assert_raise(ArgumentError) do
      buffer.file_format = :beos
    end
    buffer.file_format = "dos"
    assert_equal(:dos, buffer.file_format)
    buffer.file_format = "mac"
    assert_equal(:mac, buffer.file_format)
    buffer.file_format = "unix"
    assert_equal(:unix, buffer.file_format)
    buffer.file_format = "Dos"
    assert_equal(:dos, buffer.file_format)
    buffer.file_format = "Mac"
    assert_equal(:mac, buffer.file_format)
    buffer.file_format = "Unix"
    assert_equal(:unix, buffer.file_format)
    assert_raise(ArgumentError) do
      buffer.file_format = "beos"
    end
  end

  def test_re_search_forward
    buffer = Buffer.new(<<EOF)
Hello World
あいうえお
hello world
あいうえお
EOF
    buffer.beginning_of_buffer
    assert_equal(11, buffer.re_search_forward("world"))
    assert_equal(11, buffer.point)
    buffer.beginning_of_buffer
    assert_equal(39, buffer.re_search_forward(/world/))
    assert_equal(39, buffer.point)
    buffer[:case_fold_search] = false
    buffer.beginning_of_buffer
    assert_equal(39, buffer.re_search_forward("world"))
    assert_equal(39, buffer.point)
    buffer.beginning_of_buffer
    assert_equal(27, buffer.re_search_forward("あいうえお"))
    assert_equal(27, buffer.point)
    buffer.insert("foo")
    buffer.backward_delete_char(3)
    assert_equal(33, buffer.re_search_forward("[a-z]+"))
    assert_equal(33, buffer.point)
    assert_equal(55, buffer.re_search_forward("[あ-お]+"))
    assert_equal(55, buffer.point)

    buffer.beginning_of_buffer
    assert_raise(SearchError) do
      buffer.re_search_forward("bar")
    end
    assert_raise(SearchError) do
      buffer.re_search_forward("\0") # NUL is in the gap
    end
    buffer.next_line
    buffer.delete_char
    buffer.insert("x") # create invalid byte sequence in the gap
    buffer.beginning_of_buffer
    assert_equal(53, buffer.re_search_forward("あいうえお"))

    buffer = Buffer.new(<<EOF)
hello world
あいうえお
hello world
かきくけこ
EOF
    buffer.next_line
    buffer.end_of_line
    buffer.insert("foo")
    buffer.backward_delete_char(3)
    buffer.beginning_of_line
    buffer.next_line
    buffer.next_line
    buffer.delete_char
    buffer.insert("x") # create invalid byte sequence in the gap
    buffer.beginning_of_buffer
    assert_equal(53, buffer.re_search_forward("きくけこ"))
    buffer.beginning_of_buffer
    assert_equal(53, buffer.re_search_forward("(あか)|(きく)(けこ)"))
    assert_equal("きくけこ", buffer.match_string(0))
    assert_equal(nil, buffer.match_string(1))
    assert_equal("きく", buffer.match_string(2))
    assert_equal("けこ", buffer.match_string(3))
    buffer.beginning_of_buffer
    buffer.replace_match("\\\\ <\\&><\\1><\\2><\\3>")
    assert_equal(<<EOF, buffer.to_s)
hello world
あいうえお
hello world
x\\ <きくけこ><><きく><けこ>
EOF
    buffer.undo
    assert_equal(<<EOF, buffer.to_s)
hello world
あいうえお
hello world
xきくけこ
EOF
    buffer.redo
    assert_equal(<<EOF, buffer.to_s)
hello world
あいうえお
hello world
x\\ <きくけこ><><きく><けこ>
EOF

    buffer.beginning_of_buffer
    buffer.forward_char(8)
    buffer.insert("foo")
    buffer.backward_delete_char(3)
    buffer.beginning_of_buffer
    assert_equal(11, buffer.re_search_forward("world"))

    buffer = Buffer.new("\0\0\0\0\x81\x82\x83foo bar".b,
                        file_encoding: Encoding::ASCII_8BIT)
    assert_equal(10, buffer.re_search_forward("foo"))
  end

  def test_re_search_backward
    buffer = Buffer.new(<<EOF)
hello world
あいうえお
hello world
あいうえお
EOF
    buffer.end_of_buffer
    assert_equal(56, buffer.re_search_backward(""))
    assert_equal(56, buffer.point)
    assert_equal(38, buffer.re_search_backward("[a-z]+"))
    assert_equal(38, buffer.point)
    buffer.beginning_of_buffer
    assert_raise(SearchError) do
      buffer.re_search_backward("world")
    end
    buffer.forward_char(8)
    assert_raise(SearchError) do
      buffer.re_search_backward("world")
    end
  end

  def test_replace_regexp_forward
    buffer = Buffer.new(<<EOF)
hello world
goodbye world
hello world
EOF
    buffer.end_of_line
    buffer.replace_regexp_forward("([a-z]+) ([a-z]+)",
                                  "\\\\ <\\&> (\\1) (\\2)")
    assert_equal(<<EOF, buffer.to_s)
hello world
\\ <goodbye world> (goodbye) (world)
\\ <hello world> (hello) (world)
EOF
  end

  def test_transpose_chars
    buffer = Buffer.new(<<EOF)
hello world
あいうえお
EOF
    buffer.beginning_of_buffer
    assert_raise(RangeError) do
      buffer.transpose_chars
    end
    buffer.forward_char
    buffer.transpose_chars
    buffer = Buffer.new(<<EOF)
hello world
いあうえお
EOF
    buffer.end_of_buffer
    buffer.transpose_chars
    buffer = Buffer.new(<<EOF.chop)
hello world
いあうえ
お
EOF
    buffer.beginning_of_buffer
    buffer.end_of_line
    buffer.transpose_chars
    buffer = Buffer.new(<<EOF.chop)
hello wordl
いあうえ
お
EOF
  end

  def test_undo
    Tempfile.create("test_buffer") do |f|
      f.print(<<EOF)
Hello world
I'm shugo
EOF
      f.close
      buffer = Buffer.open(f.path)
      assert_equal(false, buffer.modified?)
      buffer.delete_char("Hello".size)
      buffer.insert("Goodbye")
      assert_equal(true, buffer.modified?)
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

      buffer.undo
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
How are you?
EOF
      buffer.undo
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
EOF
      2.times { buffer.undo }
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm shugo
EOF
      2.times { buffer.undo }
      assert_equal(false, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Hello world
I'm shugo
EOF

      assert_raise(EditorError) do
        buffer.undo
      end

      2.times { buffer.redo }
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm shugo
EOF
      2.times { buffer.redo }
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
EOF

      buffer.save
      assert_equal(false, buffer.modified?)
      2.times { buffer.undo }
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm shugo
EOF
      2.times { buffer.redo }
      assert_equal(false, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
EOF

      buffer.end_of_buffer
      buffer.insert("This is the last line\n")
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
This is the last line
EOF

      buffer.undo
      assert_equal(false, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
EOF

      2.times { buffer.undo }
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm shugo
EOF

      2.times { buffer.redo }
      assert_equal(false, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
EOF

      buffer.redo
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
This is the last line
EOF

      assert_raise(EditorError) do
        buffer.redo
      end
    end
  end

  def test_undo_merge
    buffer = Buffer.new
    buffer.insert("foo")
    buffer.insert("bar", true)
    assert_equal("foobar", buffer.to_s)
    buffer.undo
    assert_equal("", buffer.to_s)
  end

  def test_undo_limit
    Tempfile.create("test_buffer") do |f|
      buffer = Buffer.new(<<EOF, undo_limit: 4)
Hello world
I'm shugo
EOF
      assert_equal(false, buffer.modified?)
      buffer.delete_char("Hello".size)
      buffer.insert("Goodbye")
      assert_equal(true, buffer.modified?)
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

      buffer.undo
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
How are you?
EOF
      buffer.undo
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm tired
EOF
      2.times { buffer.undo }
      assert_equal(true, buffer.modified?)
      assert_equal(<<EOF, buffer.to_s)
Goodbye world
I'm shugo
EOF

      assert_raise(EditorError) do
        buffer.undo
      end
    end
  end

  def test_s_new_buffer
    buffer = Buffer.new_buffer("Untitled")
    assert_equal("Untitled", buffer.name)
    assert_equal(1, Buffer.count)
    assert_equal(buffer, Buffer["Untitled"])

    buffer2 = Buffer.new_buffer("Untitled")
    assert_equal("Untitled<2>", buffer2.name)
    assert_equal(2, Buffer.count)
    assert_equal(buffer2, Buffer["Untitled<2>"])
  end

  def test_s_find_file
    Tempfile.create("test_buffer") do |f|
      f.print("hello world\n")
      f.close

      buffer = Buffer.find_file(f.path)
      assert_equal(File.basename(f.path), buffer.name)
      assert_equal(1, Buffer.count)
      assert_equal(buffer, Buffer[buffer.name])
      assert_equal(File.read(f.path), buffer.to_s)

      buffer2 = Buffer.find_file(f.path)
      assert_equal(buffer, buffer2)
      assert_equal(1, Buffer.count)

      buffer3 = Buffer.find_file("no_such_file")
      assert_equal("no_such_file", buffer3.name)
      assert_equal(true, buffer3.new_file?)
    end
  end

  def test_s_last
    assert_equal(nil, Buffer.last)

    Buffer.current = Buffer.new_buffer("foo")
    assert_equal("foo", Buffer.current.name)
    assert_equal(nil, Buffer.last)

    Buffer.current = Buffer.new_buffer("bar")
    assert_equal("bar", Buffer.current.name)
    assert_equal("foo", Buffer.last.name)

    Buffer.current = Buffer.new_buffer("baz")
    assert_equal("baz", Buffer.current.name)
    assert_equal("bar", Buffer.last.name)

    Buffer.current.kill
    Buffer.current = Buffer.last
    assert_equal("bar", Buffer.current.name)
    assert_equal("foo", Buffer.last.name)

    Buffer.current.kill
    Buffer.current = Buffer.last
    assert_equal("foo", Buffer.current.name)
    assert_equal(nil, Buffer.last)

    Buffer.current.kill
    Buffer.current = Buffer.last
    assert_equal(nil, Buffer.current)
    assert_equal(nil, Buffer.last)
  end

  def test_s_auto_detect_encodings
    old_encodings = Buffer.auto_detect_encodings
    begin
      Buffer.auto_detect_encodings = [Encoding::ISO_8859_1, Encoding::US_ASCII]
      assert_equal([Encoding::ISO_8859_1, Encoding::US_ASCII],
                   Buffer.auto_detect_encodings)
    ensure
      Buffer.auto_detect_encodings = old_encodings
    end
  end

  def test_s_names
    assert_equal([], Buffer.names)
    foo = Buffer.new_buffer("foo")
    assert_equal(["foo"], Buffer.names)
    Buffer.new_buffer("bar")
    assert_equal(["foo", "bar"], Buffer.names)
    Buffer.new_buffer("baz")
    assert_equal(["foo", "bar", "baz"], Buffer.names)
    foo.kill
    assert_equal(["bar", "baz"], Buffer.names)
  end

  def test_s_each
    a = []
    Buffer.each { |i| a.push(i) }
    assert_equal(true, a.empty?)

    foo = Buffer.new_buffer("foo")
    a = []
    Buffer.each { |i| a.push(i) }
    assert_equal([foo], a)

    bar = Buffer.new_buffer("bar")
    baz = Buffer.new_buffer("baz")
    a = []
    Buffer.each { |i| a.push(i) }
    assert_equal([foo, bar, baz], a)
  end

  def test_set_name
    buffer = Buffer.new
    assert_equal(nil, buffer.name)
    buffer.name = "foo"
    assert_equal("foo", buffer.name)

    buffer2 = Buffer.new_buffer("bar")
    assert_equal("bar", buffer2.name)
    assert_equal(buffer2, Buffer["bar"])
    buffer2.name = "baz"
    assert_equal("baz", buffer2.name)
    assert_equal(buffer2, Buffer["baz"])
    assert_equal(nil, Buffer["bar"])
  end

  def test_current?
    buffer = Buffer.new
    assert_equal(false, buffer.current?)
    Buffer.current = buffer
    assert_equal(true, buffer.current?)
    Buffer.current = nil
    assert_equal(false, buffer.current?)
  end

  def test_point_min_max
    buffer = Buffer.new
    assert_equal(0, buffer.point_min)
    assert_equal(0, buffer.point_max)
    buffer.insert("foo")
    assert_equal(0, buffer.point_min)
    assert_equal(3, buffer.point_max)
    buffer.insert("あいうえお")
    assert_equal(0, buffer.point_min)
    assert_equal(18, buffer.point_max)
  end
  
  def test_goto_char
    buffer = Buffer.new
    buffer.insert("fooあいうえお")
    buffer.goto_char(0)
    assert_equal(0, buffer.point)
    buffer.goto_char(3)
    assert_equal(3, buffer.point)
    buffer.goto_char(6)
    assert_equal(6, buffer.point)
    buffer.goto_char(18)
    assert_equal(18, buffer.point)
    assert_raise(RangeError) do
      buffer.goto_char(-1)
    end
    assert_raise(RangeError) do
      buffer.goto_char(19)
    end
    assert_raise(ArgumentError) do
      buffer.goto_char(7) # in the middle of a character
    end
    buffer.file_encoding = Encoding::ASCII_8BIT
    buffer.goto_char(7)
    assert_equal(7, buffer.point)
  end

  def test_mark
    buffer = Buffer.new
    mark = buffer.new_mark
    assert_equal(0, mark.location)
    buffer.insert("12345")
    assert_equal(0, mark.location)
    mark2 = buffer.new_mark
    assert_equal(5, mark2.location)
    buffer.insert("6789")
    assert_equal(0, mark.location)
    assert_equal(5, mark2.location)
    buffer.point_to_mark(mark2)
    buffer.backward_char
    assert_equal(false, buffer.point_at_mark?(mark2))
    assert_equal(true, buffer.point_before_mark?(mark2))
    assert_equal(false, buffer.point_after_mark?(mark2))
    buffer.forward_char(2)
    assert_equal(false, buffer.point_at_mark?(mark2))
    assert_equal(false, buffer.point_before_mark?(mark2))
    assert_equal(true, buffer.point_after_mark?(mark2))
    buffer.point_to_mark(mark2)
    assert_equal(true, buffer.point_at_mark?(mark2))
    assert_equal(false, buffer.point_before_mark?(mark2))
    assert_equal(false, buffer.point_after_mark?(mark2))
    assert_equal(5, buffer.point)
    buffer.beginning_of_buffer
    buffer.insert("x")
    assert_equal(0, mark.location)
    assert_equal(6, mark2.location)
    buffer.mark_to_point(mark)
    assert_equal(1, mark.location)
    buffer.delete_char
    assert_equal(1, mark.location)
    assert_equal(5, mark2.location)
    buffer.point_to_mark(mark2)
    buffer.backward_delete_char
    assert_equal(1, mark.location)
    assert_equal(4, mark2.location)
    buffer.forward_char
    buffer.backward_delete_char
    assert_equal(1, mark.location)
    assert_equal(4, mark2.location)
    buffer.point_to_mark(mark)
    buffer.forward_char(2)
    buffer.backward_delete_char(2)
    assert_equal(1, mark.location)
    assert_equal(2, mark2.location)
    buffer.point_to_mark(mark)
    buffer.backward_delete_char
    assert_equal(0, mark.location)
    assert_equal(1, mark2.location)
    buffer.exchange_point_and_mark(mark2)
    assert_equal(1, buffer.point)
    assert_equal(0, mark2.location)
    assert_raise(EditorError) do
      buffer.exchange_point_and_mark(nil)
    end
  end

  def test_visible_mark
    buffer = Buffer.new("foobar")
    buffer.forward_char(3)
    assert_equal(nil, buffer.visible_mark)
    buffer.set_visible_mark
    assert_equal(3, buffer.visible_mark.location)
    buffer.delete_visible_mark
    assert_equal(nil, buffer.visible_mark)
  end

  def test_yank
    buffer = Buffer.new(<<EOF)
foo
bar
baz
EOF
    3.times do
      buffer.kill_line
      buffer.next_line
    end
    buffer.yank
    assert_equal("\n\n\nbaz", buffer.to_s)
    2.times do
      buffer.yank_pop
      assert_equal("\n\n\nbar", buffer.to_s)
      buffer.yank_pop
      assert_equal("\n\n\nfoo", buffer.to_s)
      buffer.yank_pop
      assert_equal("\n\n\nbaz", buffer.to_s)
    end
  end

  def test_gap_to_user
    buffer = Buffer.new("foobar")
    buffer.forward_char(3)
    buffer.insert("123")
    assert_equal(6, buffer.send(:gap_to_user, 6))
    assert_raise(RangeError) do
      buffer.send(:gap_to_user, 7)
    end
    assert_raise(RangeError) do
      buffer.send(:gap_to_user, 6 + Buffer::GAP_SIZE - 1)
    end
    assert_equal(6, buffer.send(:gap_to_user, 6 + Buffer::GAP_SIZE))
  end

  def test_attributes
    buffer = Buffer.new
    buffer2 = Buffer.new
    assert_equal(nil, buffer[:foo])
    assert_equal(nil, buffer2[:foo])
    buffer[:foo] = "abc"
    buffer2[:foo] = "def"
    assert_equal("abc", buffer[:foo])
    assert_equal("def", buffer2[:foo])
  end

  def test_s_minibuffer
    buffer = Buffer.minibuffer
    assert_equal("", buffer.to_s)
    buffer2 = Buffer.minibuffer
    assert_same(buffer, buffer2)
  end

  def test_find_or_new
    buffer = Buffer.find_or_new("foo")
    assert_equal("foo", buffer.name)
    buffer2 = Buffer.find_or_new("foo")
    assert_same(buffer, buffer2)
  end

  def test_inspect
    buffer = Buffer.new
    assert_match(/\A#<Buffer:0x[0-9a-f]+>\z/, buffer.inspect)
    buffer2 = Buffer.new(name: "foo")
    assert_equal("#<Buffer:foo>", buffer2.inspect)
  end

  def test_goto_line
    buffer = Buffer.new(<<EOF)
foo
bar
baz
quux
quuux
EOF
    buffer.goto_line(0)
    assert_equal(1, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.goto_line(1)
    assert_equal(1, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.goto_line(2)
    assert_equal(2, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.goto_line(4)
    assert_equal(4, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.goto_line(5)
    assert_equal(5, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.goto_line(6)
    assert_equal(6, buffer.current_line)
    assert_equal(1, buffer.current_column)
    buffer.goto_line(7)
    assert_equal(6, buffer.current_line)
    assert_equal(1, buffer.current_column)
  end

  def test_binary
    data = (0..255).to_a.pack("C*")
    buffer = Buffer.new(data)
    assert_equal(false, buffer.binary?)
    buffer = Buffer.new(data, file_encoding: Encoding::ASCII_8BIT)
    assert_equal(true, buffer.binary?)
    assert_raise(RangeError) do
      buffer.backward_char
    end
    buffer.end_of_buffer
    assert_raise(RangeError) do
      buffer.forward_char
    end
    buffer.beginning_of_buffer
    buffer.forward_char(0xe3)
    assert_equal("\xe3".force_encoding(Encoding::ASCII_8BIT),
                 buffer.byte_after)
    assert_equal("\xe3".force_encoding(Encoding::ASCII_8BIT),
                 buffer.char_after)
  end

  def test_get_line_and_column
    buffer = Buffer.new(<<EOF)
hello world
あいうえお
EOF
    assert_equal([1, 1], buffer.get_line_and_column(0))
    buffer.forward_char(7)
    assert_equal([1, 8], buffer.get_line_and_column(buffer.point))
    buffer.next_line
    buffer.beginning_of_line
    assert_equal([2, 1], buffer.get_line_and_column(buffer.point))
    buffer.forward_char(2)
    assert_equal([2, 3], buffer.get_line_and_column(buffer.point))
    buffer.end_of_buffer
    assert_equal([3, 1], buffer.get_line_and_column(buffer.point))
  end

  def test_save_excursion
    buffer = Buffer.new(<<EOF)
hello world
あいうえお
EOF
    buffer.next_line
    buffer.set_mark
    buffer.forward_char(2)
    buffer.save_excursion do
      buffer.backward_char(3)
      buffer.backward_delete_char(3)
    end
    assert_equal(15, buffer.point)
    assert_equal(9, buffer.mark)
  end
end
