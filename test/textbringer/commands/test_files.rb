require_relative "../../test_helper"

class TestFiles < Textbringer::TestCase
  def test_find_file
    mkcdtmpdir do
      find_file("foo.txt")
      assert_equal(true, Buffer.current.new_file?)
      assert_equal("", Buffer.current.to_s)
      
      File.write("hello.txt", "hello world\n")
      find_file("hello.txt")
      assert_equal(false, Buffer.current.new_file?)
      assert_equal("hello world\n", Buffer.current.to_s)
    end
  end

  def test_find_file_with_editorconfig
    mkcdtmpdir do
      File.write(".editorconfig", <<EOF)
root = true

[*.txt]
charset = utf-16le
end_of_line = crlf
indent_style = space
indent_size = 4

[*.rb]
charset = utf-8
end_of_line = lf
indent_style = tab
indent_size = 3
tab_width = 3

[*.mac]
end_of_line = cr
EOF

      find_file("foo.txt")
      assert_equal(Encoding::UTF_16LE, Buffer.current.file_encoding)
      assert_equal(:dos, Buffer.current.file_format)
      assert_equal(false, Buffer.current[:indent_tabs_mode])
      assert_equal(4, Buffer.current[:indent_level])
      assert_equal(8, Buffer.current[:tab_width])
      
      File.write("bar.rb", <<EOF)
class Foo
	def foo
		puts "foo"
	end
end
EOF
      find_file("bar.rb")
      assert_equal(Encoding::UTF_8, Buffer.current.file_encoding)
      assert_equal(:unix, Buffer.current.file_format)
      assert_equal(true, Buffer.current[:indent_tabs_mode])
      assert_equal(3, Buffer.current[:indent_level])
      assert_equal(3, Buffer.current[:tab_width])

      find_file("baz.mac")
      assert_equal(:mac, Buffer.current.file_format)
    end
  end

  def test_save_buffer
    mkcdtmpdir do |dir|
      insert("foo")
      push_keys("scratch.txt\n")
      save_buffer
      assert_equal(File.expand_path("scratch.txt"), Buffer.current.file_name)
      assert_equal("foo", File.read("scratch.txt"))
      
      File.write("hello.txt", "hello world\n")
      find_file("hello.txt")
      kill_word
      insert("goodbye")
      save_buffer
      assert_equal("goodbye world\n", File.read("hello.txt"))
      t = Time.now - 10
      kill_line
      File.utime(t, t, "hello.txt")
      push_keys("no\n")
      save_buffer
      assert_equal("goodbye world\n", File.read("hello.txt"))
      push_keys("yes\n")
      save_buffer
      assert_equal("goodbye\n", File.read("hello.txt"))
    end
  end

  def test_write_file
    mkcdtmpdir do |dir|
      insert("foo")
      write_file("scratch.txt")
      assert_equal(File.expand_path("scratch.txt"), Buffer.current.file_name)
      assert_equal("foo", File.read("scratch.txt"))
      insert("bar")
      push_keys("n")
      write_file("scratch.txt")
      assert_equal("foo", File.read("scratch.txt"))
      push_keys("y")
      write_file("scratch.txt")
      assert_equal("foobar", File.read("scratch.txt"))
      Dir.mkdir("d")
      write_file("d")
      assert_equal("foobar", File.read("d/scratch.txt"))
    end
  end

  def test_set_buffer_file_encoding
    set_buffer_file_encoding("cp932")
    assert_equal(Encoding::Windows_31J, Buffer.current.file_encoding)
  end

  def test_set_buffer_file_format
    set_buffer_file_format("dos")
    assert_equal(:dos, Buffer.current.file_format)
  end

  def test_pwd
    pwd
    assert_equal(Dir.pwd, Window.echo_area.message)
  end

  def test_chdir
    d = Dir.pwd
    begin
      chdir(__dir__)
      assert_equal(__dir__, Dir.pwd)
    ensure
      Dir.chdir(d)
    end
  end
end
