require_relative "../test_helper"

class TestRubyMode < Test::Unit::TestCase
  include Textbringer

  def setup
    @buffer = Buffer.new
    @ruby_mode = RubyMode.new(@buffer)
  end

  def test_indent_line
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
end
