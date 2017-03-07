require_relative "../test_helper"

class TestKillRing < Textbringer::TestCase
  def test_push
    ring = Ring.new(3)
    assert_raise(EditorError) do
      ring.current
    end
    ring.push("foo")
    assert_equal("foo", ring.current)
    ring.push("bar")
    assert_equal("bar", ring.current)
    ring.push("baz")
    assert_equal("baz", ring.current)
    assert_equal("bar", ring.rotate(1))
    assert_equal("foo", ring.rotate(1))
    assert_equal("baz", ring.rotate(1))
    assert_equal("bar", ring.rotate(1))
    ring.push("quux")
    assert_equal("quux", ring.current)
    assert_equal("bar", ring.rotate(1))
    assert_equal("foo", ring.rotate(1))
    assert_equal("quux", ring.rotate(1))

    ring.clear
    ring.push("foo")
    ring.push("bar")
    ring.push("baz")
    ring.push("quux")
    assert_equal("quux", ring.current)
    assert_equal("baz", ring.rotate(1))
    assert_equal("bar", ring.rotate(1))
    assert_equal("quux", ring.rotate(1))
    assert_equal("quux", ring.pop)
    assert_equal("baz", ring.current)
  end
end
