require_relative "../../test_helper"
require "tempfile"

class TestServer < Textbringer::TestCase
  setup do
    CONFIG[:server_uri] = "druby://localhost:8787"
  end

  def test_visit_file
    server_start
    Tempfile.create do |f|
      t = Thread.start {
        tb = DRbObject.new_with_uri(CONFIG[:server_uri])
        tb.visit_file(f.path)
      } 
      Controller.current.call_next_block
      assert_equal(f.path, Buffer.current.file_name)
      insert("Hello, world!")
      save_buffer
      server_edit_done
      assert_equal("Hello, world!", f.read)
      assert_equal(:done, t.value)
    end
  ensure
    server_kill
  end

  def test_eval
    foo = Buffer.new_buffer("foo")
    switch_to_buffer(foo)
    server_start
    Tempfile.create do |f|
      t = Thread.start {
        tb = DRbObject.new_with_uri(CONFIG[:server_uri])
        tb.eval('Buffer.current.name')
      } 
      Controller.current.call_next_block
      assert_equal('"foo"', t.value)
    end
  ensure
    server_kill
  end
end
