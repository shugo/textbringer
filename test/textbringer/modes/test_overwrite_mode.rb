require_relative "../../test_helper"
require "tmpdir"

class TestOverwriteMode < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("overwrite_test")
    switch_to_buffer(@buffer)
  end

  def test_overwrite_mode
    insert("abcdefg\n")
    insert("あいうえお\n")
    beginning_of_buffer
    Controller.current.last_key = "x"
    overwrite_mode
    self_insert
    assert_equal(<<~EOF, Buffer.current.to_s)
      xbcdefg
      あいうえお
    EOF
    forward_char(2)
    Controller.current.last_key = "y"
    self_insert
    assert_equal(<<~EOF, Buffer.current.to_s)
      xbcyefg
      あいうえお
    EOF
    Controller.current.last_key = "か"
    self_insert
    assert_equal(<<~EOF, Buffer.current.to_s)
      xbcyかfg
      あいうえお
    EOF
    next_line
    Controller.current.last_key = "き"
    self_insert
    assert_equal(<<~EOF, Buffer.current.to_s)
      xbcyかfg
      あいうきお
    EOF
    Controller.current.current_prefix_arg = [3]
    Controller.current.last_key = "z"
    self_insert
    assert_equal(<<~EOF.chomp, Buffer.current.to_s)
      xbcyかfg
      あいうきzzz
    EOF
    overwrite_mode
    beginning_of_buffer
    Controller.current.current_prefix_arg = nil
    Controller.current.last_key = "q"
    self_insert
    assert_equal(<<~EOF.chomp, Buffer.current.to_s)
      qxbcyかfg
      あいうきzzz
    EOF
  end

  def test_undo_overwrite
    insert("abcdefg\n")
    insert("あいうえお\n")
    beginning_of_buffer
    Controller.current.last_key = "x"
    overwrite_mode
    self_insert
    assert_equal(<<~EOF, Buffer.current.to_s)
      xbcdefg
      あいうえお
    EOF
    Controller.current.last_key = "y"
    self_insert
    assert_equal(<<~EOF, Buffer.current.to_s)
      xycdefg
      あいうえお
    EOF
    Controller.current.last_key = "か"
    self_insert
    assert_equal(<<~EOF, Buffer.current.to_s)
      xyかdefg
      あいうえお
    EOF
    undo
    assert_equal(<<~EOF, Buffer.current.to_s)
      abcdefg
      あいうえお
    EOF
  end
end
