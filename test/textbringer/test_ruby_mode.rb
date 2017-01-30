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

  def test_indent_line_begin
    @buffer.insert(<<EOF.chop)
  begin
foo
rescue
bar
ensure
baz
end
EOF
    @buffer.goto_line(2)
    while !@buffer.end_of_buffer?
      @ruby_mode.indent_line
      @buffer.forward_line
    end
    assert_equal(<<EOF.chop, @buffer.to_s)
  begin
    foo
  rescue
    bar
  ensure
    baz
  end
EOF
  end
  
  def test_indent_line_unmatch
    @buffer.insert(<<EOF.chop)
  def foo
    bar do
      baz {
      end
    }
quux
EOF
    assert_raise(EditorError) do
      @ruby_mode.indent_line
    end
  end
  
  def test_indent_line_unmatch_2
    @buffer.insert(<<EOF.chop)
  def foo
    bar {
      baz do
      }
    end
quux
EOF
    assert_raise(EditorError) do
      @ruby_mode.indent_line
    end
  end
  
  def test_indent_line_multiline_args
    @buffer.insert(<<EOF)
foo(x, y,
    z) {
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo(x, y,
    z) {
  
EOF

    @buffer.clear
    @buffer.insert(<<EOF)
foo x, y,
  z {
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo x, y,
  z {
  
EOF
  end

  def test_indent_line_in_string
    @buffer.insert(<<EOF.chop)
x = "
     foo
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
x = "
     foo
EOF

    @buffer.clear
    @buffer.insert(<<EOF.chop)
x = <<END
     foo
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
x = <<END
     foo
EOF

    @buffer.clear
    @buffer.insert(<<EOF.chop)
x = <<END
     foo
   bar
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
x = <<END
     foo
   bar
EOF
  end
  
  def test_newline_and_reindent
    @buffer.insert(<<EOF.chop)
class foo
  def bar
EOF
    @ruby_mode.newline_and_reindent
    assert_equal(<<EOF.chop, @buffer.to_s)
class foo
  def bar
    
EOF
    @ruby_mode.newline_and_reindent
    assert_equal(<<EOF.chop, @buffer.to_s)
class foo
  def bar

    
EOF
  end
  
  def test_forward_definition
    @buffer.insert(<<EOF.chop)
# encoding: us-ascii

class foo
  def bar
    x
    y
  end

  def baz
    a
    b
  end
EOF
    @buffer.beginning_of_buffer
    @ruby_mode.forward_definition
    assert_equal(3, @buffer.current_line)
    assert_equal(1, @buffer.current_column)
    @ruby_mode.forward_definition
    assert_equal(4, @buffer.current_line)
    assert_equal(3, @buffer.current_column)
    @ruby_mode.forward_definition
    assert_equal(9, @buffer.current_line)
    assert_equal(3, @buffer.current_column)
    @ruby_mode.forward_definition
    assert_equal(true, @buffer.end_of_buffer?)
  end
  
  def test_backward_definition
    @buffer.insert(<<EOF.chop)
# encoding: us-ascii

class foo
  def bar
    x
    y
  end

  def baz
    a
    b
  end
EOF
    @buffer.end_of_buffer
    @ruby_mode.backward_definition
    assert_equal(9, @buffer.current_line)
    assert_equal(3, @buffer.current_column)
    @ruby_mode.backward_definition
    assert_equal(4, @buffer.current_line)
    assert_equal(3, @buffer.current_column)
    @ruby_mode.backward_definition
    assert_equal(3, @buffer.current_line)
    assert_equal(1, @buffer.current_column)
    @ruby_mode.backward_definition
    assert_equal(true, @buffer.beginning_of_buffer?)
  end
end
