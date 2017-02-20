require_relative "../../test_helper"

class TestRegister < Textbringer::TestCase
  def test_jump_to_register
    buffer = Buffer.new_buffer("foo")
    switch_to_buffer(buffer)
    insert(<<EOF)
foo
bar
baz
EOF
    goto_char(4)
    point_to_register("a")
    register = REGISTERS["a"]
    assert_equal(buffer, register.buffer)
    assert_equal(4, register.mark.location)
    beginning_of_buffer
    switch_to_buffer("*scratch*")
    jump_to_register("a")
    assert_equal(buffer, Buffer.current)
    assert_equal(4, buffer.point)

    goto_char(8)
    old_mark = REGISTERS["a"].mark
    push_keys("a")
    point_to_register
    assert_equal(true, old_mark.deleted?)
    beginning_of_buffer
    switch_to_buffer("*scratch*")
    push_keys("a")
    jump_to_register
    assert_equal(buffer, Buffer.current)
    assert_equal(8, buffer.point)

    assert_raise(ArgumentError) do
      point_to_register(0)
    end
    assert_raise(ArgumentError) do
      jump_to_register(0)
    end
  end
end
