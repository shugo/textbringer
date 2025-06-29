require_relative "../../test_helper"

class TestRectangle < Textbringer::TestCase
  def test_kill_rectangle
    buffer = Buffer.current
    buffer.insert(<<-EOF)
foo
bar
baz
EOF
    buffer.beginning_of_buffer
    buffer.forward_char(1)
    buffer.set_mark
    buffer.forward_line(2)
    buffer.forward_char(2)
    kill_rectangle
    assert_equal({ type: :rectangle, data: ["oo", "ar", "az"] }, KILL_RING.current)
    assert_equal(<<-EOF, buffer.to_s)
f
b
b
EOF

    buffer.end_of_buffer
    yank
    assert_equal(<<-EOF.chomp, buffer.to_s)
f
b
b
oo
ar
az
EOF
  end
end
