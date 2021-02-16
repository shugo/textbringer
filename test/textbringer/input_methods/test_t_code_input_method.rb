require_relative "../../test_helper"

class TestTCodeInputMethod < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("test")
    @buffer.toggle_input_method
    @im = @buffer.input_method
    switch_to_buffer(@buffer)
  end

  def test_insert_direct
    assert_equal(?`, @im.handle_event(?`))
  end

  def test_insert_kanji
    assert_equal(nil, @im.handle_event(?z))
    assert_equal(?字, @im.handle_event(?/))
  end

  def test_bushu_composition
    @buffer.insert("五口")
    assert_equal(nil, @im.handle_event(?j))
    assert_equal(?吾, @im.handle_event(?f))
    assert_equal("", @buffer.to_s)
  end

  def test_mazegaki_conversion_from_many
    @buffer.insert("かんじ")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    
    assert_equal("△かんじ", @buffer.to_s)
    assert_equal(<<EOF.chop, Buffer["*T-Code Help*"].to_s)
 -    -    -    -     -        -     -    -    -    -
[-    -    漢字 監事] -        - [   -    -    -    -]
[換字 幹事 完治 寛治] 感じ     - [   -    -    -    -]
[-    -    -    -   ] -        - [   -    -    -    -]   (1/1)
EOF
    assert_equal(nil, @im.handle_event(?e))
    assert_equal("漢字", @buffer.to_s)
  end

  def test_mazegaki_conversion_from_two
    @buffer.insert("かん字")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    
    assert_equal("△{換字,漢字}", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?f))
    assert_equal("漢字", @buffer.to_s)
  end

  def test_mazegaki_conversion_from_one
    @buffer.insert("漢じ")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    
    assert_equal("△漢字", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?\C-m))
    assert_equal("漢字", @buffer.to_s)
  end

  def test_mazegaki_conversion_with_inflection
    @buffer.insert("おもう")
    assert_equal(nil, @im.handle_event(?5))
    assert_equal(nil, @im.handle_event(?8))
    assert_equal("△おもう", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?d))
    assert_equal("思う", @buffer.to_s)
  end

  def test_relimit_right
    @buffer.insert("おもう")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    assert_equal("お△もう", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?>))
    assert_equal("おも△う", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?>))
    assert_equal("△おもう", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?d))
    assert_equal("思う", @buffer.to_s)
  end

  def test_relimit_left
    @buffer.insert("きかんしゃ")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    assert_equal("△機関車", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?>))
    assert_equal("き△{官舎,感謝}", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?<))
    assert_equal("△機関車", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?\C-m))
    assert_equal("機関車", @buffer.to_s)
  end

  def test_show_stroke
    @buffer.insert("漢字")
    @buffer.beginning_of_buffer
    assert_equal(nil, @im.handle_event(?5))
    assert_equal(nil, @im.handle_event(?5))
    assert_equal(<<EOF, Buffer["*T-Code Help*"].to_s)
      ２            
・・・・    ・・・・
・・・・    ・・１・
・・・・    ・・・・
EOF
  end
end
