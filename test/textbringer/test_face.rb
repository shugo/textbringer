require_relative "../test_helper"

class TestFace < Textbringer::TestCase
  def setup
    Face.clear
  end
  
  def test_define
    comment = Face.define(:comment, foreground: "yellow")
    assert_equal(comment, Face[:comment])
    assert_equal(0, comment.attributes & Curses::A_BOLD)
    assert_equal(0, comment.attributes & Curses::A_UNDERLINE)
    keyword = Face.define(:keyword, foreground: "red", bold: true)
    assert_equal(keyword, Face[:keyword])
    assert_equal(Curses::A_BOLD, keyword.attributes & Curses::A_BOLD)
    assert_equal(0, keyword.attributes & Curses::A_UNDERLINE)
    keyword2 = Face.define(:keyword, foreground: "green", underline: true)
    assert_same(keyword, keyword2)
    assert_equal(keyword, Face[:keyword])
    assert_equal(0, keyword.attributes & Curses::A_BOLD)
    assert_equal(Curses::A_UNDERLINE, keyword.attributes & Curses::A_UNDERLINE)
  end
end
