require_relative "../../test_helper"

class TestProgrammingMode < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("foo.rb")
    @programming_mode = ProgrammingMode.new(@buffer)
    switch_to_buffer(@buffer)
  end

  def test_indent_line
    assert_raise(EditorError) do
      @programming_mode.indent_line
    end
  end
end
