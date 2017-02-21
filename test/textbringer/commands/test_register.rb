require_relative "../../test_helper"

class TestRegister < Textbringer::TestCase
  def setup
    super
    REGISTERS.clear
  end

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

    assert_raise(ArgumentError) do
      jump_to_register("b")
    end
    REGISTERS["b"] = "foo"
    assert_raise(ArgumentError) do
      jump_to_register("b")
    end
  end

  def test_insert_register
    buffer = Buffer.current
    insert(<<EOF)
foo
bar
baz
EOF
    goto_char(4)
    set_mark_command
    end_of_line
    copy_to_register("a")
    point_to_register("b")
    end_of_buffer
    pos = buffer.point
    insert_register("a", nil)
    assert_equal(pos, buffer.point)
    assert_equal(pos + 3, buffer.mark)
    assert_equal(<<EOF.chop, buffer.to_s)
foo
bar
baz
bar
EOF
    insert_register("a", true)
    assert_equal(pos, buffer.mark)
    assert_equal(pos + 3, buffer.point)
    assert_equal(<<EOF.chop, buffer.to_s)
foo
bar
baz
barbar
EOF
    insert_register("b")
    assert_equal(pos + 3, buffer.point)
    assert_equal(pos + 4, buffer.mark)
    assert_equal(<<EOF.chop, buffer.to_s)
foo
bar
baz
bar7bar
EOF
    beginning_of_line
    set_mark_command
    end_of_line
    copy_to_register("c", buffer.mark, buffer.point, true)
    beginning_of_buffer
    insert_register("c")
    assert_equal(<<EOF, buffer.to_s)
bar7barfoo
bar
baz
EOF
  end

  def test_append_to_register
    insert(<<EOF)
foo
bar
baz
EOF
    copy_to_register("c", 0, 3)
    append_to_register("c", 4, 7)
    append_to_register("c", 8, 11, [4])
    assert_equal("foobarbaz", REGISTERS["c"])
    assert_equal(<<EOF, Buffer.current.to_s)
foo
bar

EOF
  end

  def test_increment_register
    number_to_register(42, "a")
    increment_register(1, "a")
    assert_equal(43, REGISTERS["a"])
    increment_register(3, "a")
    assert_equal(46, REGISTERS["a"])
    increment_register(-40, "a")
    assert_equal(6, REGISTERS["a"])
    assert_raise(ArgumentError) do
      increment_register(1, "b")
    end
    insert(<<EOF)
foo
bar
baz
EOF
    copy_to_register("c", 0, 3)
    goto_char(4)
    set_mark_command
    end_of_line
    increment_register([4], "c")
    assert_equal("foobar", REGISTERS["c"])
    assert_equal(<<EOF, Buffer.current.to_s)
foo

baz
EOF
  end
end
