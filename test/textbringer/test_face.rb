require_relative "../test_helper"

class TestFace < Textbringer::TestCase
  def test_define
    foo = Face.define(:foo, foreground: "yellow")
    assert_equal(foo, Face[:foo])
    assert_equal(0, foo.attributes & Terminal::A_BOLD)
    assert_equal(0, foo.attributes & Terminal::A_UNDERLINE)
    bar = Face.define(:bar, foreground: "red", bold: true)
    assert_equal(bar, Face[:bar])
    assert_equal(Terminal::A_BOLD, bar.attributes & Terminal::A_BOLD)
    assert_equal(0, bar.attributes & Terminal::A_UNDERLINE)
    bar2 = Face.define(:bar, foreground: "green", underline: true)
    assert_same(bar, bar2)
    assert_equal(bar, Face[:bar])
    assert_equal(0, bar.attributes & Terminal::A_BOLD)
    assert_equal(Terminal::A_UNDERLINE, bar.attributes & Terminal::A_UNDERLINE)
  ensure
    Face.delete(:foo)
    Face.delete(:bar)
  end
end
