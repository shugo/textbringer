require_relative "../../test_helper"
require "tmpdir"

class TestRubyMode < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("foo.rb")
    @buffer.apply_mode(RubyMode)
    @ruby_mode = @buffer.mode
    switch_to_buffer(@buffer)
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

  def test_indent_line_in_regexp
    @buffer.insert(<<EOF.chop)
x = /
     foo
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
x = /
     foo
EOF
  end

  def test_indent_line_comma
    @buffer.insert(<<EOF.chop)
foo x,
y
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo x,
  y
EOF
  end

  def test_indent_line_comma_in_hash
    @buffer.insert(<<EOF.chop)
h = {
  x: 1,

EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
h = {
  x: 1,
  
EOF
  end

  def test_indent_line_keyword_symbol
    @buffer.insert(<<EOF.chop)
def foo
  :end
  end
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
def foo
  :end
end
EOF
  end
  
  def test_reindent_then_newline_and_indent
    @buffer.insert(<<EOF.chop)
class foo
  def bar
EOF
    @ruby_mode.reindent_then_newline_and_indent
    assert_equal(<<EOF.chop, @buffer.to_s)
class foo
  def bar
    
EOF
    @ruby_mode.reindent_then_newline_and_indent
    assert_equal(<<EOF.chop, @buffer.to_s)
class foo
  def bar

    
EOF
    @buffer.insert("end")
    @ruby_mode.reindent_then_newline_and_indent
    assert_equal(<<EOF.chop, @buffer.to_s)
class foo
  def bar

  end
  
EOF
  end

  def test_reindent_then_newline_and_indent_after_cr
    @buffer.insert("\r")
    @ruby_mode.reindent_then_newline_and_indent
    assert_equal("\r\n", @buffer.to_s)
  end

  def test_indent_region
    @buffer.insert(<<EOF)
class Foo
def foo
puts "foo"
end
end
class Bar
def bar
puts "bar"
end
end
EOF
    @buffer.goto_line(6)
    pos = @buffer.point
    @ruby_mode.indent_region(pos, @buffer.point_max)
    assert_equal(<<EOF, @buffer.to_s)
class Foo
def foo
puts "foo"
end
end
class Bar
  def bar
    puts "bar"
  end
end
EOF
    @ruby_mode.indent_region(pos, @buffer.point_min)
    assert_equal(<<EOF, @buffer.to_s)
class Foo
  def foo
    puts "foo"
  end
end
class Bar
  def bar
    puts "bar"
  end
end
EOF
    @buffer.clear
    @ruby_mode.indent_region(0, 0)
    assert_equal("", @buffer.to_s)
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

  def test_compile
    @ruby_mode.compile("#{ruby_install_name} -e 'puts %<hello world>'")
  end

  def test_symbol_pattern
    assert_match(@ruby_mode.symbol_pattern, "a")
    assert_match(@ruby_mode.symbol_pattern, "0")
    assert_match(@ruby_mode.symbol_pattern, "あ")
    assert_match(@ruby_mode.symbol_pattern, "_")
    assert_match(@ruby_mode.symbol_pattern, "?")
    assert_match(@ruby_mode.symbol_pattern, "!")
    assert_match(@ruby_mode.symbol_pattern, "$")
    assert_match(@ruby_mode.symbol_pattern, "@")
  end

  def test_default_compile_command
    Dir.mktmpdir do |dir|
      pwd = Dir.pwd
      Dir.chdir(dir)
      begin
        assert_equal(nil, @ruby_mode.default_compile_command)
        @buffer.file_name = "/path/to/foo.rb"
        assert_equal("#{ruby_install_name} /path/to/foo.rb",
                     @ruby_mode.default_compile_command)
        FileUtils.touch("Rakefile")
        assert_equal("rake", @ruby_mode.default_compile_command)
        FileUtils.touch("Gemfile")
        assert_equal("bundle exec rake", @ruby_mode.default_compile_command)
      ensure
        Dir.chdir(pwd)
      end
    end
  end

  def test_toggle_test
    Dir.mktmpdir do |dir|
      pwd = Dir.pwd
      Dir.chdir(dir)
      begin
        FileUtils.mkdir_p("app/models/")
        FileUtils.touch("app/models/sword.rb")
        FileUtils.touch("app/models/shield.rb")
        FileUtils.mkdir_p("lib/roles")
        FileUtils.touch("lib/roles/fighter.rb")
        FileUtils.touch("lib/roles/monk.rb")
        FileUtils.touch("lib/roles/white_mage.rb")
        FileUtils.mkdir_p("test/models")
        FileUtils.touch("test/models/test_sword.rb")
        FileUtils.touch("test/models/test_shield.rb")
        FileUtils.mkdir_p("test/roles")
        FileUtils.touch("test/roles/test_fighter.rb")
        FileUtils.touch("test/test_monk.rb")
        FileUtils.touch("test/roles/test_white_mage.rb")

        find_file("app/models/sword.rb")
        assert_equal(File.expand_path("app/models/sword.rb"),
                     Buffer.current.file_name)
        toggle_test_command
        assert_equal(File.expand_path("test/models/test_sword.rb"),
                     Buffer.current.file_name)
        toggle_test_command
        assert_equal(File.expand_path("app/models/sword.rb"),
                     Buffer.current.file_name)

        find_file("lib/roles/monk.rb")
        assert_equal(File.expand_path("lib/roles/monk.rb"),
                     Buffer.current.file_name)
        toggle_test_command
        assert_equal(File.expand_path("test/test_monk.rb"),
                     Buffer.current.file_name)
        toggle_test_command
        assert_equal(File.expand_path("lib/roles/monk.rb"),
                     Buffer.current.file_name)

        find_file("lib/roles/black_mage.rb")
        assert_raise(EditorError) do
          toggle_test_command
        end
        find_file("test/roles/test_black_mage.rb")
        assert_raise(EditorError) do
          toggle_test_command
        end

        find_file("foo")
        ruby_mode
        assert_raise(EditorError) do
          toggle_test_command
        end
      ensure
        Dir.chdir(pwd)
      end
    end
  end

  def test_syntax_string_here_document
    m = @ruby_mode.syntax_table[:string].match(<<~EOF)
      s = <<EOS
        hello
        world
      EOS
    EOF
    assert_equal(<<~EOF.chop, m[0])
      <<EOS
        hello
        world
      EOS
    EOF
  end

  def test_syntax_string_here_document_quoted
    m = @ruby_mode.syntax_table[:string].match(<<~EOF)
      s = <<'EOS'
        hello
        world
      EOS
    EOF
    assert_equal(<<~EOF.chop, m[0])
      <<'EOS'
        hello
        world
      EOS
    EOF
  end

  def test_syntax_string_here_document_unterminated
    m = @ruby_mode.syntax_table[:string].match(<<~EOF)
      s = <<EOS
        hello
        world
      E
    EOF
    assert_equal(nil, m)
  end
end
