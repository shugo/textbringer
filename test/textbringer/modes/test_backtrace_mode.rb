require_relative "../../test_helper"

class TestBacktraceMode < Textbringer::TestCase
  def test_jump_to_location
    pwd = Dir.pwd
    Dir.chdir(File.expand_path("../../fixtures/ctags", __dir__))
    begin
      buffer = Buffer.current
      buffer.insert("foo.rb:7: error\n")
      buffer.insert("foo.rb(10): error\n")
      buffer.insert("foo.rb:11:10: error\n")
      backtrace_mode
      beginning_of_buffer
      jump_to_source_location_command
      assert_equal("foo.rb", Buffer.current.name)
      assert_equal(7, Buffer.current.current_line)
      assert_equal(1, Buffer.current.current_column)
      switch_to_buffer(buffer)
      buffer.forward_line
      pos = buffer.point
      jump_to_source_location_command
      assert_equal(buffer, Buffer.current)
      assert_equal(pos, Buffer.current.point)
      switch_to_buffer(buffer)
      buffer.forward_line
      jump_to_source_location_command
      assert_equal("foo.rb", Buffer.current.name)
      assert_equal(11, Buffer.current.current_line)
      assert_equal(10, Buffer.current.current_column)
    ensure
      Dir.chdir(pwd)
    end
  end
end
