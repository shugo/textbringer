require_relative "../../test_helper"

class TestHangulInputMethod < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("test")
    @buffer.toggle_input_method("hangul")
    @im = @buffer.input_method
    switch_to_buffer(@buffer)
  end

  def test_single_jamo
    assert_self_insert(?ㅏ, ?k)
    assert_equal("ㅏ", @buffer.to_s)
  end

  def test_closed_syllable
    assert_self_insert(?ㅎ, ?g)
    assert_equal("ㅎ", @buffer.to_s)
    assert_self_insert(nil, ?k)
    assert_equal("하", @buffer.to_s)
    assert_self_insert(nil, ?s)
    assert_equal("한", @buffer.to_s)
  end

  def test_open_syllable
    assert_self_insert(?ㅇ, ?d)
    assert_equal("ㅇ", @buffer.to_s)
    assert_self_insert(nil, ?k)
    assert_equal("아", @buffer.to_s)
  end

  def test_multiple_open_syllables
    assert_self_insert(?ㅇ, ?d)
    assert_self_insert(nil, ?k)
    assert_equal("아", @buffer.to_s)
    assert_self_insert(nil, ?d)
    assert_equal("앙", @buffer.to_s)
    assert_self_insert(nil, @im.handle_event(?k))
    assert_equal("아아", @buffer.to_s)
  end

  def test_phrase
    assert_self_insert(?ㅇ, ?d)
    assert_self_insert(nil, ?k)
    assert_equal("아", @buffer.to_s)
    assert_self_insert(nil, ?s)
    assert_equal("안", @buffer.to_s)
    assert_self_insert(?ㄴ, ?s)
    assert_self_insert(nil, ?u)
    assert_equal("안녀", @buffer.to_s)
    assert_self_insert(nil, ?d)
    assert_equal("안녕", @buffer.to_s)
    assert_self_insert(?ㅎ, ?g)
    assert_self_insert(nil, ?k)
    assert_equal("안녕하", @buffer.to_s)
    assert_self_insert(nil, ?t)
    assert_equal("안녕핫", @buffer.to_s)
    assert_self_insert(nil, ?p)
    assert_equal("안녕하세", @buffer.to_s)
    assert_self_insert(nil, ?d)
    assert_equal("안녕하셍", @buffer.to_s)
    assert_self_insert(nil, ?y)
    assert_equal("안녕하세요", @buffer.to_s)
  end

  private

  def assert_self_insert(expected, key)
    s = @im.handle_event(key)
    @buffer.insert(s)
    assert_equal(expected, s)
  end
end
