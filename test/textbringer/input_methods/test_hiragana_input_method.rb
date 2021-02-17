require_relative "../../test_helper"

class TestHiraganaInputMethod < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("test")
    @buffer.toggle_input_method("hiragana")
    @im = @buffer.input_method
    switch_to_buffer(@buffer)
  end

  def test_insert_direct
    assert_equal(?`, @im.handle_event(?`))
    assert_equal(nil, @im.handle_event(?y))
    assert_equal(nil, @im.handle_event(?f))
    assert_equal("yf", @buffer.to_s)
  end

  def test_insert_hiragana
    assert_equal(?あ, @im.handle_event(?a))
    assert_equal(nil, @im.handle_event(?k))
    assert_equal(?か, @im.handle_event(?a))
    assert_equal(nil, @im.handle_event(?s))
    assert_equal(nil, @im.handle_event(?h))
    assert_equal(nil, @im.handle_event(?a))
    assert_equal("しゃ", @buffer.to_s)
  end
end
