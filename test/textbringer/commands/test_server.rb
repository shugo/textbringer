require_relative "../../test_helper"
require "tempfile"
require "tmpdir"
require "fileutils"

class TestServer < Textbringer::TestCase
  setup do
    @dir = Dir.mktmpdir
    @sock_path = File.expand_path("server.sock", @dir)
    CONFIG[:server_uri] = "drbunix:" + @sock_path
  end

  teardown do
    FileUtils.remove_entry(@dir)
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

  def test_server_sock_mode_no_options
    CONFIG[:server_options] = nil
    server_start
    assert_equal(0600, File.stat(@sock_path).mode & 0777)
  ensure
    server_kill
  end

  def test_server_sock_mode_empty_options
    CONFIG[:server_options] = {}
    server_start
    assert_equal(0600, File.stat(@sock_path).mode & 0777)
  ensure
    server_kill
  end

  def test_server_sock_mode_specified_options
    CONFIG[:server_options] = { UNIXFileMode: 0700 }
    server_start
    assert_equal(0700, File.stat(@sock_path).mode & 0777)
  ensure
    server_kill
  end
end
