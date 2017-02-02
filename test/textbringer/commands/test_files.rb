require_relative "../../test_helper"
require "tmpdir"

class TestFiles < Textbringer::TestCase
  def test_save_buffer
    Dir.mktmpdir do |dir|
      pwd = Dir.pwd
      Dir.chdir(dir)
      begin
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
      ensure
        Dir.chdir(pwd)
      end
    end
  end
end
