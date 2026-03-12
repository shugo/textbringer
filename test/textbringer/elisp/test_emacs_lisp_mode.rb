require_relative "../../test_helper"

class TestEmacsLispMode < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("test.el")
    @buffer.apply_mode(Textbringer::EmacsLispMode)
    switch_to_buffer(@buffer)
  end

  def test_file_name_pattern
    assert_match(Textbringer::EmacsLispMode.file_name_pattern, "foo.el")
    assert_match(Textbringer::EmacsLispMode.file_name_pattern, "/path/to/init.el")
    refute_match(Textbringer::EmacsLispMode.file_name_pattern, "foo.rb")
  end

  def test_mode_name
    assert_equal("EmacsLisp", Textbringer::EmacsLispMode.mode_name)
  end

  def test_comment_start
    assert_equal(";; ", @buffer.mode.comment_start)
  end

  def test_symbol_pattern
    assert_match(@buffer.mode.symbol_pattern, "a")
    assert_match(@buffer.mode.symbol_pattern, "-")
    assert_match(@buffer.mode.symbol_pattern, "_")
  end
end
