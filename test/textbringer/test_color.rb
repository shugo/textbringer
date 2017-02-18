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
  ensure
    Curses.colors = 256
  end
end
