require_relative "../../test_helper"

class TestBufferListMode < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("*Buffer List*")
    @mode = BufferListMode.new(@buffer)
    switch_to_buffer(@buffer)
  end

  def test_this_window
    foo = Buffer.new_buffer("foo")
    @buffer.insert("foo")
    @buffer.beginning_of_buffer
    @mode.this_window
    assert_equal(foo, Buffer.current)
  end
end
