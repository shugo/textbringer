require_relative "../test_helper"

class TestRubyMode < Test::Unit::TestCase
  include Textbringer

  def setup
    @buffer = Buffer.new
    @ruby_mode = RubyMode.new(@buffer)
  end

  def test_indent_line_class
    @ruby_mode.indent_line
    assert_equal("", @buffer.to_s)
    @buffer.insert("class Foo")
    @ruby_mode.indent_line
    assert_equal("class Foo", @buffer.to_s)
    @buffer.insert("\n")
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
class Foo
  
EOF
    @buffer.insert("def bar\n")
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
class Foo
  def bar
    
EOF
    @buffer.insert("3.times {\n")
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
class Foo
  def bar
    3.times {
      
EOF
    @buffer.insert("puts 'Ho!'\n")
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
class Foo
  def bar
    3.times {
      puts 'Ho!'
      
EOF
    @buffer.insert("}")
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
class Foo
  def bar
    3.times {
      puts 'Ho!'
    }
EOF
    @buffer.insert("\nend")
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
class Foo
  def bar
    3.times {
      puts 'Ho!'
    }
  end
EOF
    @buffer.insert("\nend")
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
class Foo
  def bar
    3.times {
      puts 'Ho!'
    }
  end
end
EOF
  end

  def test_indent_line_paren
    @buffer.insert(<<EOF.chop)
foo(123,
456
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo(123,
    456
EOF
  end

  def test_indent_line_modifier
    @buffer.insert(<<EOF)
def foo(x)
  return if x < 0
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
def foo(x)
  return if x < 0
  
EOF
  end
  
  def test_indent_line_stabby_lambda
    @buffer.insert(<<EOF)
f = ->(x, y) {
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
f = ->(x, y) {
  
EOF
    @buffer.insert("x + y\n}")
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
f = ->(x, y) {
  x + y
}
EOF
  end
  
  def test_indent_line_op_cont
    @buffer.insert(<<EOF.chop)
foo = bar +
baz
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo = bar +
  baz
EOF
  end
  
  def test_indent_line_brace_block_with_param
    @buffer.insert(<<EOF.chop)
foo { |x|
bar
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo { |x|
  bar
EOF
  end
end
