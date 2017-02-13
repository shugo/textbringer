require_relative "../test_helper"

class TestFace < Textbringer::TestCase
  def test_define
    foo = Face.define(:foo, foreground: "yellow")
    assert_equal(foo, Face[:foo])
    assert_equal(0, foo.attributes & Curses::A_BOLD)
    assert_equal(0, foo.attributes & Curses::A_UNDERLINE)
    bar = Face.define(:bar, foreground: "red", bold: true)
    assert_equal(bar, Face[:bar])
    assert_equal(Curses::A_BOLD, bar.attributes & Curses::A_BOLD)
    assert_equal(0, bar.attributes & Curses::A_UNDERLINE)
    bar2 = Face.define(:bar, foreground: "green", underline: true)
    assert_same(bar, bar2)
    assert_equal(bar, Face[:bar])
    assert_equal(0, bar.attributes & Curses::A_BOLD)
    assert_equal(Curses::A_UNDERLINE, bar.attributes & Curses::A_UNDERLINE)
  ensure
    Face.delete(:foo)
    Face.delete(:bar)
  end
end
