require_relative "../../test_helper"

class TestTCodeInputMethod < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("test")
    @buffer.toggle_input_method("t_code")
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
    assert_equal(nil, @im.handle_event(?f))
    assert_equal("吾", @buffer.to_s)
  end

  def test_bushu_composition_failure
    @buffer.insert("五日")
    assert_equal(nil, @im.handle_event(?j))
    assert_equal(nil, @im.handle_event(?f))
    assert_equal("五日", @buffer.to_s)
  end

  def test_mazegaki_conversion_from_many
    @buffer.insert("かんじ")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    
    assert_equal("△かんじ", @buffer.to_s)
    assert_equal(<<EOF.chop, Buffer["*T-Code Help*"].to_s)
 -    -    -    -     -        -     -    -    -    -
[-    -    -    -   ] -        - [   -    -    -    -]
[幹事 換字 感じ 漢字] 監事     - [   -    -    -    -]
[-    -    -    -   ] -        - [   -    -    -    -]   (1/1)
EOF
    assert_equal(nil, @im.handle_event(?f))
    assert_equal("漢字", @buffer.to_s)
  end

  def test_mazegaki_conversion_pagination
    @buffer.insert("こう")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    
    assert_equal("△こう", @buffer.to_s)
    assert_equal(<<EOF.chop, Buffer["*T-Code Help*"].to_s)
 -  -  -  -   -    -   -  -  -  -
[効 公 候 光] 功  塙 [坑 喉 垢 好]
[倖 佼 交 仰] 侯  后 [厚 勾 口 向]
[-  -  -  - ] -    - [ -  -  -  -]   (1/2)
EOF
    assert_equal(nil, @im.handle_event(" "))
    assert_equal(<<EOF.chop, Buffer["*T-Code Help*"].to_s)
 -  -  -  -   -    -   -  -  -  -
[康 広 巷 幸] 庚   - [抗 慌  -  -]
[巧 宏 孔 孝] 工  恒 [弘 廣 後 恰]
[-  -  -  - ] -    - [ -  -  -  -]   (2/2)
EOF
    assert_equal(nil, @im.handle_event(?w))
    assert_equal("広", @buffer.to_s)
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

  def test_mazegaki_conversion_automatic_finish
    @buffer.insert("漢じ")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    
    assert_equal("△漢字", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?k))
    assert_equal("漢字", @buffer.to_s)
    assert_equal(?の, @im.handle_event(?d))
  end

  def test_mazegaki_conversion_cancel
    @buffer.insert("漢じ")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    
    assert_equal("△漢字", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?\C-g))
    assert_equal("漢じ", @buffer.to_s)
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

    @buffer.clear
    @buffer.insert("かえる")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    assert_equal("△蛙", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?>))
    assert_equal("△かえる", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?s))
    assert_equal("帰る", @buffer.to_s)

    @buffer.clear
    @buffer.insert("かえる")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    assert_equal("△蛙", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?>))
    assert_equal("△かえる", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?>))
    assert_equal("△かえる", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?d))
    assert_equal("買える", @buffer.to_s)
  end

  def test_relimit_left
    @buffer.insert("きかんしゃ")
    assert_equal(nil, @im.handle_event(?f))
    assert_equal(nil, @im.handle_event(?j))
    assert_equal("△機関車", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?>))
    assert_equal("き△かんしゃ", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?<))
    assert_equal("△機関車", @buffer.to_s)
    assert_equal(nil, @im.handle_event(?\C-m))
    assert_equal("機関車", @buffer.to_s)
  end

  def test_mazegaki_conversion_failure
    @buffer.insert("ん")
    assert_equal(nil, @im.handle_event(?f))
    assert_raise(EditorError) do
      @im.handle_event(?j)
    end
    assert_equal("ん", @buffer.to_s)
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
