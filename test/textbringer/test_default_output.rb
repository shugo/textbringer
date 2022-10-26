require_relative "../test_helper"

class TestDefaultOutput < Textbringer::TestCase
  setup do
    @default_output = DefaultOutput.new
  end

  def test_write
    Buffer.current.clear
    @default_output.write("hello world")
    assert_equal("hello world", Buffer.current.to_s)
  end

  def test_flush
    assert_nothing_raised do
      @default_output.flush
    end
  end

  def test_printf
    Buffer.current.clear
    @default_output.printf("%x", 10)
    assert_equal("a", Buffer.current.to_s)
  end
end
