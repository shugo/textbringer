require_relative "../../test_helper"

class TestWindows < Textbringer::TestCase
  def test_resize_window
    assert_nothing_raised do
      resize_window
    end
  end

  def test_recenter
    (1..100).each do |i|
      insert("line#{i}\n")
    end
    goto_line(21)
    resize_window
    Buffer.current.point_to_mark(Window.current.top_of_window)
    assert_equal(10, Buffer.current.current_line)
  end
end
