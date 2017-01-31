require_relative "../test_helper"

class TestKillRing < Textbringer::TestCase
  include Textbringer

  def test_push
    kill_ring = KillRing.new(3)
    assert_raise(EditorError) do
      kill_ring.current
    end
    kill_ring.push("foo")
    assert_equal("foo", kill_ring.current)
    kill_ring.push("bar")
    assert_equal("bar", kill_ring.current)
    kill_ring.push("baz")
    assert_equal("baz", kill_ring.current)
    assert_equal("bar", kill_ring.current(1))
    assert_equal("foo", kill_ring.current(1))
    assert_equal("baz", kill_ring.current(1))
    assert_equal("bar", kill_ring.current(1))
    kill_ring.push("quux")
    assert_equal("quux", kill_ring.current)
    assert_equal("bar", kill_ring.current(1))
    assert_equal("foo", kill_ring.current(1))
    assert_equal("quux", kill_ring.current(1))

    kill_ring.clear
    kill_ring.push("foo")
    kill_ring.push("bar")
    kill_ring.push("baz")
    kill_ring.push("quux")
    assert_equal("quux", kill_ring.current)
    assert_equal("baz", kill_ring.current(1))
    assert_equal("bar", kill_ring.current(1))
    assert_equal("quux", kill_ring.current(1))
  end
end
