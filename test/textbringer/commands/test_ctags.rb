require_relative "../../test_helper"

class TestCtags < Textbringer::TestCase
  def test_find_tag
    old_tag_mark_limit = CONFIG[:tag_mark_limit]
    CONFIG[:tag_mark_limit] = 4
    pwd = Dir.pwd
    Dir.chdir(File.expand_path("../../fixtures/ctags", __dir__))
    begin
      assert_raise(EditorError) do
        find_tag(true)
      end
      find_file("test.rb")
      re_search_forward(/^foo/)
      find_tag
      assert_equal("foo.rb", Buffer.current.name)
      assert_equal(2, Buffer.current.current_line)
      assert_equal(1, Buffer.current.current_column)
      find_tag(true)
      assert_equal("test.rb", Buffer.current.name)
      assert_equal(1, Buffer.current.current_line)
      assert_equal(1, Buffer.current.current_column)
      re_search_forward(/^bar/)
      pos = Buffer.current.point
      find_tag
      assert_equal("foo.rb", Buffer.current.name)
      assert_equal(6, Buffer.current.current_line)
      assert_equal(1, Buffer.current.current_column)
      pop_tag_mark
      assert_equal("test.rb", Buffer.current.name)
      assert_equal(pos, Buffer.current.point)
      re_search_forward(/^baz/)
      find_tag
      assert_equal("foo.rb", Buffer.current.name)
      assert_equal(10, Buffer.current.current_line)
      assert_equal(1, Buffer.current.current_column)
      pop_tag_mark
      re_search_backward(/^foo/)
      find_tag
      assert_equal("foo.rb", Buffer.current.name)
      assert_equal(2, Buffer.current.current_line)
      assert_equal(1, Buffer.current.current_column)
      find_tag(true)
      assert_equal("test.rb", Buffer.current.name)
      assert_equal(1, Buffer.current.current_line)
      assert_equal(1, Buffer.current.current_column)
      assert_raise(EditorError) do
        find_tag(true)
      end
      find_tag(:-)
      assert_equal("foo.rb", Buffer.current.name)
      assert_equal(2, Buffer.current.current_line)
      assert_equal(1, Buffer.current.current_column)
      assert_raise(EditorError) do
        find_tag(:-)
      end
      pop_tag_mark
      re_search_forward(/quux/)
      assert_raise(EditorError) do
        find_tag
      end
      assert_equal("test.rb", Buffer.current.name)
      re_search_forward(/quuux/)
      assert_raise(EditorError) do
        find_tag
      end
      end_of_buffer
      assert_raise(EditorError) do
        find_tag
      end
      3.times do |i|
        pop_tag_mark
      end
      assert_raise(EditorError) do
        pop_tag_mark
      end
    ensure
      Dir.chdir(pwd)
      CONFIG[:tag_mark_limit] = old_tag_mark_limit
    end
  end
end
