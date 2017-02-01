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
FGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~あいうえお
EOF
  end
  
  def test_redisplay_escape_binary
    @buffer.file_encoding = Encoding::ASCII_8BIT
    @buffer.insert((0..0xff).map(&:chr).join)
    @window.redisplay
    assert_equal(<<'EOF' + "\n" * 12, window_string(@window.window))
^@^A^B^C^D^E^F^G^H      
^K^L^M^N^O^P^Q^R^S^T^U^V^W^X^Y^Z^[^\^]^^^_ !"#$%&'()*+,-./0123456789:;<=>?@ABCDE
FGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~<80><81><82><83><84>
<85><86><87><88><89><8A><8B><8C><8D><8E><8F><90><91><92><93><94><95><96><97><98>
<99><9A><9B><9C><9D><9E><9F><A0><A1><A2><A3><A4><A5><A6><A7><A8><A9><AA><AB><AC>
<AD><AE><AF><B0><B1><B2><B3><B4><B5><B6><B7><B8><B9><BA><BB><BC><BD><BE><BF><C0>
<C1><C2><C3><C4><C5><C6><C7><C8><C9><CA><CB><CC><CD><CE><CF><D0><D1><D2><D3><D4>
<D5><D6><D7><D8><D9><DA><DB><DC><DD><DE><DF><E0><E1><E2><E3><E4><E5><E6><E7><E8>
<E9><EA><EB><EC><ED><EE><EF><F0><F1><F2><F3><F4><F5><F6><F7><F8><F9><FA><FB><FC>
<FD><FE><FF>
EOF
  end

  def test_split
    Window.current.split
    assert_equal(3, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(12, Window.windows[0].lines)
    assert_equal(true, Window.windows[0].current?)
    assert_equal(false, Window.windows[0].echo_area?)
    assert_equal(12, Window.windows[1].y)
    assert_equal(11, Window.windows[1].lines)
    assert_equal(false, Window.windows[1].current?)
    assert_equal(false, Window.windows[1].echo_area?)
    assert_equal(Window.windows[0].buffer, Window.windows[1].buffer)
    assert_equal(23, Window.windows[2].y)
    assert_equal(1, Window.windows[2].lines)
    assert_equal(false, Window.windows[2].current?)
    assert_equal(true, Window.windows[2].echo_area?)

    Window.current.split
    Window.current.split
    assert_raise(EditorError) do
      Window.current.split
    end
  end

  def test_s_delete_window
    assert_raise(EditorError) do
      Window.delete_window
    end
    Window.current.split
    assert_equal(3, Window.windows.size)
    window = Window.current
    Window.current = Window.echo_area
    assert_raise(EditorError) do
      Window.delete_window
    end
    Window.current = window
    Window.delete_window
    assert_equal(true, window.deleted?)
    assert_equal(2, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(23, Window.windows[0].lines)
    assert_equal(23, Window.windows[1].y)
    assert_equal(1, Window.windows[1].lines)
    assert_equal(Window.windows[0], Window.current)

    Window.current.split
    assert_equal(3, Window.windows.size)
    window = Window.current = Window.windows[1]
    Window.delete_window
    assert_equal(true, window.deleted?)
    assert_equal(2, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(23, Window.windows[0].lines)
    assert_equal(23, Window.windows[1].y)
    assert_equal(1, Window.windows[1].lines)
    assert_equal(Window.windows[0], Window.current)
  end

  def test_s_delete_other_windows
    Window.current = Window.echo_area
    assert_raise(EditorError) do
      Window.delete_other_windows
    end

    window = Window.current = Window.windows[0]
    Window.current.split
    Window.current.split
    assert_equal(4, Window.windows.size)
    Window.delete_other_windows
    assert_equal(false, window.deleted?)
    assert_equal(2, Window.windows.size)
    assert_equal(0, Window.windows[0].y)
    assert_equal(23, Window.windows[0].lines)
    assert_equal(23, Window.windows[1].y)
    assert_equal(1, Window.windows[1].lines)
    assert_equal(Window.windows[0], Window.current)
  end

  def test_s_other_window
    assert_equal(true, @window.current?)
    Window.other_window
    assert_equal(true, @window.current?)

    @window.split
    assert_equal(@window, Window.current)
    Window.other_window
    assert_equal(Window.windows[1], Window.current)
    Window.other_window
    assert_equal(@window, Window.current)

    @window.split
    assert_equal(@window, Window.current)
    Window.other_window
    assert_equal(Window.windows[1], Window.current)
    Window.other_window
    assert_equal(Window.windows[2], Window.current)
    Window.other_window
    assert_equal(@window, Window.current)

    Window.echo_area.active = true
    Window.other_window
    assert_equal(Window.windows[1], Window.current)
    Window.other_window
    assert_equal(Window.windows[2], Window.current)
    Window.other_window
    assert_equal(Window.windows[3], Window.current)
    Window.other_window
    assert_equal(@window, Window.current)
  end

  def test_s_resize
    old_lines = Window.lines
    old_columns = Window.columns
    Window.lines = 40
    Window.columns = 60
    begin
      Window.resize
      assert_equal(0, Window.windows[0].y)
      assert_equal(0, Window.windows[0].x)
      assert_equal(60, Window.windows[0].columns)
      assert_equal(39, Window.windows[0].lines)
      assert_equal(39, Window.windows[1].y)
      assert_equal(0, Window.windows[1].x)
      assert_equal(60, Window.windows[1].columns)
      assert_equal(1, Window.windows[1].lines)

      @window.split
      assert_equal(3, Window.windows.size)
      assert_equal(0, Window.windows[0].y)
      assert_equal(0, Window.windows[0].x)
      assert_equal(60, Window.windows[0].columns)
      assert_equal(20, Window.windows[0].lines)
      assert_equal(20, Window.windows[1].y)
      assert_equal(0, Window.windows[1].x)
      assert_equal(60, Window.windows[1].columns)
      assert_equal(19, Window.windows[1].lines)
      assert_equal(39, Window.windows[2].y)
      assert_equal(0, Window.windows[2].x)
      assert_equal(60, Window.windows[2].columns)
      assert_equal(1, Window.windows[2].lines)

      Window.lines = 24
      Window.other_window
      Window.resize
      assert_equal(3, Window.windows.size)
      assert_equal(Window.windows[1], Window.current)
      assert_equal(0, Window.windows[0].y)
      assert_equal(0, Window.windows[0].x)
      assert_equal(60, Window.windows[0].columns)
      assert_equal(20, Window.windows[0].lines)
      assert_equal(20, Window.windows[1].y)
      assert_equal(0, Window.windows[1].x)
      assert_equal(60, Window.windows[1].columns)
      assert_equal(3, Window.windows[1].lines)
      assert_equal(23, Window.windows[2].y)
      assert_equal(0, Window.windows[2].x)
      assert_equal(60, Window.windows[2].columns)
      assert_equal(1, Window.windows[2].lines)

      Window.lines = 23
      Window.resize
      assert_equal(2, Window.windows.size)
      assert_equal(Window.windows[0], Window.current)
      assert_equal(0, Window.windows[0].y)
      assert_equal(0, Window.windows[0].x)
      assert_equal(60, Window.windows[0].columns)
      assert_equal(22, Window.windows[0].lines)
      assert_equal(22, Window.windows[1].y)
      assert_equal(0, Window.windows[1].x)
      assert_equal(60, Window.windows[1].columns)
      assert_equal(1, Window.windows[1].lines)
    ensure
      Window.lines = old_lines
      Window.columns = old_columns
    end
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
