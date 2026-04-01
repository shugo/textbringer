require_relative "../test_helper"

class TestColor < Textbringer::TestCase
  def test_aref
    assert_equal(Curses::COLOR_BLACK, Color["black"])
    assert_equal(Curses::COLOR_MAGENTA, Color["magenta"])
    assert_equal(Curses::COLOR_WHITE, Color["white"])
    assert_equal(8, Color["brightblack"])
    assert_equal(15, Color["brightwhite"])

    assert_equal(16, Color["#000000"])
    assert_equal(231, Color["#FFFFFF"])
    assert_equal(196, Color["#FF0000"])
    assert_equal(55, Color["#5F00AF"])
    assert_equal(191, Color["#DFFF5F"])
    assert_equal(44, Color["#00D7D7"])

    assert_equal(96, Color["#75507B"])
    assert_equal(190, Color["#CCEE00"])
    assert_equal(128, Color["#AA00CC"])

    assert_equal(0, Color[0])
    assert_equal(8, Color[8])
    assert_equal(255, Color[255])

    Curses.colors = 16
    assert_equal(15, Color["brightwhite"])
    assert_equal(-1, Color["#000000"])

    Curses.colors = 8
    assert_equal(Curses::COLOR_WHITE, Color["white"])
    assert_equal(-1, Color["brightblack"])

    assert_raise(EditorError) do
      Color["foo"]
    end
  ensure
    Curses.colors = 256
  end

  def test_direct_color
    Curses.colors = 16_777_216

    # Hex colors should be packed as direct RGB
    assert_equal(0xFF0000, Color["#FF0000"])
    assert_equal(0x00FF00, Color["#00FF00"])
    assert_equal(0x0000FF, Color["#0000FF"])
    assert_equal(0x000000, Color["#000000"])
    assert_equal(0xFFFFFF, Color["#FFFFFF"])
    assert_equal(0x5F00AF, Color["#5F00AF"])

    # Basic color names should map to xterm default RGB values
    assert_equal(-1, Color["default"])
    assert_equal(0x000000, Color["black"])
    assert_equal(0xCD0000, Color["red"])
    assert_equal(0x00CD00, Color["green"])
    assert_equal(0xCDCD00, Color["yellow"])
    assert_equal(0x0000EE, Color["blue"])
    assert_equal(0xCD00CD, Color["magenta"])
    assert_equal(0x00CDCD, Color["cyan"])
    assert_equal(0xE5E5E5, Color["white"])
    assert_equal(0xFF00FF, Color["brightmagenta"])
    assert_equal(0xFFFFFF, Color["brightwhite"])

    # Integer passthrough still works
    assert_equal(0xFF0000, Color[0xFF0000])
    assert_equal(0, Color[0])

    assert_raise(EditorError) do
      Color["foo"]
    end
  ensure
    Curses.colors = 256
  end

  def test_direct_color_detection
    Curses.colors = 256
    refute Color.direct_color?

    Curses.colors = 16_777_216
    assert Color.direct_color?
  ensure
    Curses.colors = 256
  end
end
