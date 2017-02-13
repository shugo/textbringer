require_relative "../test_helper"

class TestWindow < Textbringer::TestCase
  include Textbringer

  def setup
    super
    @window = Window.current
    @lines = Window.lines - 1
    @columns = Window.columns
    @buffer = Buffer.new_buffer("foo")
    @window.buffer = @buffer
  end

  def test_redisplay
    @window.redisplay
    expected_mode_line = format("%-#{@columns}s",
                                "foo [UTF-8/unix] <EOF> 1,1 (Fundamental)")
    assert_match(expected_mode_line, @window.mode_line.contents[0])
    assert(@window.window.contents.all?(&:empty?))

    @buffer.insert("hello world")
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert(@window.window.contents.drop(1).all?(&:empty?))

    @buffer.insert("\n" + "x" * @columns)
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert(@window.window.contents.drop(2).all?(&:empty?))

    @buffer.insert("x" * @columns)
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert_equal("x" * @columns, @window.window.contents[2])
    assert(@window.window.contents.drop(3).all?(&:empty?))

    @buffer.insert("あ" * (@columns / 2))
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert_equal("x" * @columns, @window.window.contents[2])
    assert_equal("あ" * (@columns / 2), @window.window.contents[3])
    assert(@window.window.contents.drop(4).all?(&:empty?))

    @buffer.insert("x" + "い" * (@columns / 2))
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert_equal("x" * @columns, @window.window.contents[2])
    assert_equal("あ" * (@columns / 2), @window.window.contents[3])
    assert_equal("x" + "い" * (@columns / 2 - 1), @window.window.contents[4])
    assert_equal("い", @window.window.contents[5])
    assert(@window.window.contents.drop(6).all?(&:empty?))

    @buffer.insert("\n" * (@lines - 7))
    @buffer.insert("y" * @columns)
    @buffer.insert("z")
    @buffer.backward_char(2)
    @window.redisplay
    assert_equal("hello world", @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert_equal("x" * @columns, @window.window.contents[2])
    assert_equal("あ" * (@columns / 2), @window.window.contents[3])
    assert_equal("x" + "い" * (@columns / 2 - 1), @window.window.contents[4])
    assert_equal("い", @window.window.contents[5])
    assert(@window.window.contents.drop(6).take(@lines - 8).all?(&:empty?))
    assert_equal("y" * @columns, @window.window.contents[@lines - 2])

    @buffer.forward_char
    @window.redisplay
    assert_equal("x" * @columns, @window.window.contents[0])
    assert_equal("x" * @columns, @window.window.contents[1])
    assert_equal("あ" * (@columns / 2), @window.window.contents[2])
    assert_equal("x" + "い" * (@columns / 2 - 1), @window.window.contents[3])
    assert_equal("い", @window.window.contents[4])
    assert(@window.window.contents.drop(5).take(@lines - 8).all?(&:empty?))
    assert_equal("y" * @columns, @window.window.contents[@lines - 3])
    assert_equal("z", @window.window.contents[@lines - 2])
  end

  def test_redisplay_tabs
    @buffer.insert("\tfoo\n")
    @buffer.insert("bar\tbaz\n")
    @buffer.insert("quuuuuux\tquux\n")
    @window.redisplay
    assert_equal(<<EOF + "\n" * 19, window_string(@window.window))
        foo
bar     baz
quuuuuux        quux
EOF
  end

  def test_redisplay_escape_utf8
    @buffer.insert((0..0x7f).map(&:chr).join + "あいうえお")
    @window.redisplay
    assert_equal(<<'EOF' + "\n" * 19, window_string(@window.window))
^@^A^B^C^D^E^F^G^H      
^K^L^M^N^O^P^Q^R^S^T^U^V^W^X^Y^Z^[^\^]^^^_ !"#$%&'()*+,-./0123456789:;<=>?@ABCDE
FGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~^?あいうえお
EOF
  end
  
  def test_redisplay_escape_binary
    @buffer.file_encoding = Encoding::ASCII_8BIT
    @buffer.insert((0..0xff).map(&:chr).join)
    @window.redisplay
    assert_equal(<<'EOF' + "\n" * 12, window_string(@window.window))
^@^A^B^C^D^E^F^G^H      
^K^L^M^N^O^P^Q^R^S^T^U^V^W^X^Y^Z^[^\^]^^^_ !"#$%&'()*+,-./0123456789:;<=>?@ABCDE
FGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~^?<80><81><82><83><84>
<85><86><87><88><89><8A><8B><8C><8D><8E><8F><90><91><92><93><94><95><96><97><98>
<99><9A><9B><9C><9D><9E><9F><A0><A1><A2><A3><A4><A5><A6><A7><A8><A9><AA><AB><AC>
<AD><AE><AF><B0><B1><B2><B3><B4><B5><B6><B7><B8><B9><BA><BB><BC><BD><BE><BF><C0>
<C1><C2><C3><C4><C5><C6><C7><C8><C9><CA><CB><CC><CD><CE><CF><D0><D1><D2><D3><D4>
<D5><D6><D7><D8><D9><DA><DB><DC><DD><DE><DF><E0><E1><E2><E3><E4><E5><E6><E7><E8>
<E9><EA><EB><EC><ED><EE><EF><F0><F1><F2><F3><F4><F5><F6><F7><F8><F9><FA><FB><FC>
<FD><FE><FF>
EOF
  end

  def test_redisplay_escape_ambiwidth
    old_width = CONFIG[:east_asian_ambiguous_width]
    begin
      @buffer.insert(<<EOF)
　今から約千七百八十年ほど前のことである。
　一人の旅人があった。
　腰に、一剣を佩《は》いているほか、身なりはいたって見すぼらしいが、眉《まゆ》は秀《ひい》で、唇《くち》は紅《あか》く、とりわけ聡明《そうめい》そうな眸《ひとみ》や、豊《ゆた》かな頬をしていて、つねにどこかに微笑をふくみ、総じて賤《いや》しげな容子《ようす》がなかった。
　年の頃は二十四、五。
　草むらの中に、ぽつねんと坐って、膝をかかえこんでいた。
　悠久《ゆうきゅう》と水は行く——
　微風は爽《さわ》やかに鬢《びん》をなでる。
　涼秋の八月だ。
　そしてそこは、黄河の畔《ほとり》の——黄土層の低い断《き》り岸《ぎし》であった。
EOF
      CONFIG[:east_asian_ambiguous_width] = 1
      @window.redisplay
      assert_equal(<<'EOF' + "\n" * 10, window_string(@window.window))
　今から約千七百八十年ほど前のことである。
　一人の旅人があった。
　腰に、一剣を佩《は》いているほか、身なりはいたって見すぼらしいが、眉《まゆ》は
秀《ひい》で、唇《くち》は紅《あか》く、とりわけ聡明《そうめい》そうな眸《ひとみ
》や、豊《ゆた》かな頬をしていて、つねにどこかに微笑をふくみ、総じて賤《いや》し
げな容子《ようす》がなかった。
　年の頃は二十四、五。
　草むらの中に、ぽつねんと坐って、膝をかかえこんでいた。
　悠久《ゆうきゅう》と水は行く——
　微風は爽《さわ》やかに鬢《びん》をなでる。
　涼秋の八月だ。
　そしてそこは、黄河の畔《ほとり》の——黄土層の低い断《き》り岸《ぎし》であった。
EOF
      CONFIG[:east_asian_ambiguous_width] = 2
      @window.redisplay
      assert_equal(<<'EOF' + "\n" * 9, window_string(@window.window))
　今から約千七百八十年ほど前のことである。
　一人の旅人があった。
　腰に、一剣を佩《は》いているほか、身なりはいたって見すぼらしいが、眉《まゆ》は
秀《ひい》で、唇《くち》は紅《あか》く、とりわけ聡明《そうめい》そうな眸《ひとみ
》や、豊《ゆた》かな頬をしていて、つねにどこかに微笑をふくみ、総じて賤《いや》し
げな容子《ようす》がなかった。
　年の頃は二十四、五。
　草むらの中に、ぽつねんと坐って、膝をかかえこんでいた。
　悠久《ゆうきゅう》と水は行く——
　微風は爽《さわ》やかに鬢《びん》をなでる。
　涼秋の八月だ。
　そしてそこは、黄河の畔《ほとり》の——黄土層の低い断《き》り岸《ぎし》であった
。
EOF
    ensure
      CONFIG[:east_asian_ambiguous_width] = old_width
    end
  end

  def test_redisplay_ruby_mode
    @buffer.apply_mode(RubyMode)
    @buffer.insert(<<'EOF')
# Foo
class Foo
  def foo
    puts "foo"
  end
end
EOF
    @window.redisplay
    assert_equal(<<'EOF' + "\n" * 16, window_string(@window.window))
# Foo
class Foo
  def foo
    puts "foo"
  end
end
EOF
  end

  def test_s_current
    window = Window.current
    window.split
    assert_equal(3, Window.windows.size)
    Window.delete_window
    Window.current = window
    assert_not_equal(window, Window.current)
    assert_equal(Window.windows.first, Window.current)
  end

  def test_s_readraw
    assert_nothing_raised do
      Window.redraw
    end
  end

  def test_read_char
    @window.window.push_key("a")
    assert_equal("a", @window.read_char)

    @window.window.push_key(Curses::KEY_RIGHT)
    assert_equal(:right, @window.read_char)

    @window.window.push_key(PDCurses::ALT_0 + 3)
    assert_equal("\e", @window.read_char)
    assert_equal("3", @window.read_char)

    @window.window.push_key(PDCurses::ALT_A + 5)
    assert_equal("\e", @window.read_char)
    assert_equal("f", @window.read_char)

    PDCurses.PDC_set_key_modifiers(PDCurses::KEY_MODIFIER_CONTROL)
    @window.window.push_key("a")
    assert_equal("\C-a", @window.read_char)
    @window.window.push_key("?")
    assert_equal("\x7f", @window.read_char)

    PDCurses.PDC_set_key_modifiers(PDCurses::KEY_MODIFIER_ALT)
    @window.window.push_key("\0")
    @window.window.push_key("a")
    assert_equal("\e", @window.read_char)
    assert_equal("a", @window.read_char)
  ensure
    PDCurses.PDC_set_key_modifiers(0)
  end

  def test_read_char_nonblock
    @window.window.push_key("a")
    assert_equal("a", @window.read_char_nonblock)
  end

  def test_wait_input
    assert_equal(nil, @window.wait_input(1))

    @window.window.push_key("a")
    assert_equal("a", @window.wait_input(1))

    PDCurses.PDC_set_key_modifiers(PDCurses::KEY_MODIFIER_ALT)
    @window.window.push_key("\0")
    @window.window.push_key("a")
    assert_equal("\e", @window.read_char)
    assert_equal("a", @window.wait_input(1))
  ensure
    PDCurses.PDC_set_key_modifiers(0)
  end

  def test_has_input?
    assert_equal(false, @window.has_input?)

    @window.window.push_key("a")
    assert_equal(true, @window.has_input?)

    PDCurses.PDC_set_key_modifiers(PDCurses::KEY_MODIFIER_ALT)
    @window.window.push_key("\0")
    @window.window.push_key("a")
    assert_equal("\e", @window.read_char)
    assert_equal(true, @window.has_input?)
  ensure
    PDCurses.PDC_set_key_modifiers(0)
  end

  def test_echo_area_redisplay
    Window.echo_area.redisplay
    assert_equal("\n", window_string(Window.echo_area.window))
    Window.echo_area.show("foo")
    Window.echo_area.redisplay
    assert_equal("foo\n", window_string(Window.echo_area.window))
    Window.echo_area.clear_message
    Window.echo_area.prompt = "bar: "
    Window.echo_area.redisplay
    assert_equal("bar: \n", window_string(Window.echo_area.window))
    Buffer.minibuffer.insert("baz")
    Window.echo_area.redisplay
    assert_equal("bar: baz\n", window_string(Window.echo_area.window))
    Window.echo_area.clear
    Window.echo_area.redisplay
    assert_equal("\n", window_string(Window.echo_area.window))
  end

  private

  def window_string(window)
    window.contents.join("\n") + "\n"
  end
end
