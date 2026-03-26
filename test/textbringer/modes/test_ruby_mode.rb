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

  def test_indent_line_paren_with_newline
    @buffer.insert(<<EOF.chop)
foo(
123
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo(
  123
EOF
  end

  def test_indent_line_paren_with_newline_and_comma
    @buffer.insert(<<EOF.chop)
foo(
  123,
456
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo(
  123,
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
  
  def test_indent_line_method_chain
    @buffer.insert(<<EOF.chop)
foo
.baz
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo
  .baz
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
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
  def foo
    bar do
      baz {
      end
    }
      quux
EOF
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
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
  def foo
    bar {
      baz do
      }
    end
    quux
EOF
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

  def test_indent_line_after_regexp_with_flags
    @buffer.insert(<<EOF.chop)
def foo
  x = /abc/x
bar
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
def foo
  x = /abc/x
  bar
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

  def test_indent_line_at_toplevel
    @buffer.insert(<<EOF.chop)
foo(bar,
    baz)
    quux
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo(bar,
    baz)
quux
EOF
  end

  def test_indent_line_after_hash_assignment
    @buffer.insert(<<EOF.chop)
  def foo
    h =
      {
        x: 1,
        y: 2,
      }
bar
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
  def foo
    h =
      {
        x: 1,
        y: 2,
      }
    bar
EOF
  end

  def test_indent_line_after_class
    @buffer.insert(<<EOF.chop)
  class Foo
    def foo
    end
  end
Foo.new.foo
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
  class Foo
    def foo
    end
  end
  Foo.new.foo
EOF
  end

  def test_indent_line_extra_end
    @buffer.insert(<<EOF.chop)
        if foo
        end
      end
    end
end
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
        if foo
        end
      end
    end
  end
EOF
  end

  def test_indent_line_embexpr_end
    @buffer.insert(<<EOF.chop)
        if foo
        end
      }
    }
}
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
        if foo
        end
      }
    }
  }
EOF
  end

  def test_indent_line_embedded_string
    @buffer.insert(<<EOF.chop)
        if foo
          "#{123}"
end
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
        if foo
          "#{123}"
        end
EOF
  end

  def test_indent_line_def_in_brace_and_paren
    @buffer.insert(<<EOF.chop)
        foo(bar {
          def baz
          end
        })
quux
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
        foo(bar {
          def baz
          end
        })
        quux
EOF
  end
  
  def test_indent_line_endless_method_definition
    @buffer.insert(<<EOF.chop)
  def foo = 1
bar
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
  def foo = 1
  bar
EOF
  end
  
  def test_indent_line_endless_method_definition_with_params
    @buffer.insert(<<EOF.chop)
  def foo(x, y = (x + 1) * 2) = [x, y]
bar
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
  def foo(x, y = (x + 1) * 2) = [x, y]
  bar
EOF
  end

  def test_indent_line_and
    @buffer.insert(<<EOF.chop)
x = y and
z
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
x = y and
  z
EOF
  end

  def test_indent_line_label
    @buffer.insert(<<EOF.chop)
foo x:
1
EOF
    @ruby_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
foo x:
  1
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
    omit_if(on_windows?)
    Dir.mktmpdir do |dir|
      pwd = Dir.pwd
      Dir.chdir(dir)
      begin
        FileUtils.mkdir_p("app/models/")
        FileUtils.touch("app/models/sword.rb")
        FileUtils.touch("app/models/shield.rb")
        FileUtils.touch("app/models/armor.rb")
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
        FileUtils.mkdir_p("spec/models")
        FileUtils.touch("spec/models/armor_spec.rb")

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

        find_file("app/models/armor.rb")
        assert_equal(File.expand_path("app/models/armor.rb"),
                     Buffer.current.file_name)
        toggle_test_command
        assert_equal(File.expand_path("spec/models/armor_spec.rb"),
                     Buffer.current.file_name)
        toggle_test_command
        assert_equal(File.expand_path("app/models/armor.rb"),
                     Buffer.current.file_name)

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

  def test_indent_new_comment_line
    @buffer.insert(<<EOF.chop)
  ### foo
EOF
    @ruby_mode.indent_new_comment_line
    assert_equal("  ### foo\n  ### ", @buffer.to_s)
  end

  def call_highlight
    highlight_on = {}
    highlight_off = {}
    ctx = HighlightContext.new(
      buffer: @buffer,
      highlight_start: @buffer.point_min,
      highlight_end: @buffer.point_max,
      highlight_on: highlight_on,
      highlight_off: highlight_off
    )
    @ruby_mode.highlight(ctx)
    [highlight_on, highlight_off]
  end

  def test_prism_highlight_keywords
    Window.has_colors = true
    @buffer.insert("def foo; end")
    @buffer.beginning_of_buffer
    highlight_on, highlight_off = call_highlight
    # "def" at position 0
    assert_equal(Face[:keyword], highlight_on[0])
    assert_equal(true, highlight_off[3])
    # "foo" at position 4 (function name after def)
    assert_equal(Face[:function_name], highlight_on[4])
    assert_equal(true, highlight_off[7])
    # "end" at position 9
    assert_equal(Face[:keyword], highlight_on[9])
    assert_equal(true, highlight_off[12])
  end

  def test_prism_highlight_comments
    Window.has_colors = true
    @buffer.insert("# comment")
    @buffer.beginning_of_buffer
    highlight_on, highlight_off = call_highlight
    assert_equal(Face[:comment], highlight_on[0])
    assert_equal(true, highlight_off[9])
  end

  def test_prism_highlight_strings
    Window.has_colors = true
    @buffer.insert('"hello"')
    @buffer.beginning_of_buffer
    highlight_on, highlight_off = call_highlight
    # STRING_BEGIN at 0
    assert_equal(Face[:string], highlight_on[0])
    assert_equal(true, highlight_off[1])
    # STRING_CONTENT at 1
    assert_equal(Face[:string], highlight_on[1])
    assert_equal(true, highlight_off[6])
    # STRING_END at 6
    assert_equal(Face[:string], highlight_on[6])
    assert_equal(true, highlight_off[7])
  end

  def test_prism_highlight_symbols
    Window.has_colors = true
    @buffer.insert(":foo")
    @buffer.beginning_of_buffer
    highlight_on, highlight_off = call_highlight
    # SYMBOL_BEGIN ":" at 0
    assert_equal(Face[:string], highlight_on[0])
    assert_equal(true, highlight_off[1])
    # IDENTIFIER "foo" at 1 (carried by in_symbol state)
    assert_equal(Face[:string], highlight_on[1])
    assert_equal(true, highlight_off[4])
  end

  def test_prism_highlight_percent_lower_i
    Window.has_colors = true
    @buffer.insert('%i(x y)')
    @buffer.beginning_of_buffer
    highlight_on, highlight_off = call_highlight
    # PERCENT_LOWER_I: %i(
    assert_equal(Face[:string], highlight_on[0])
    assert_equal(true, highlight_off[3])
    # STRING_CONTENT: x
    assert_equal(Face[:string], highlight_on[3])
    assert_equal(true, highlight_off[4])
    # STRING_CONTENT: y
    assert_equal(Face[:string], highlight_on[5])
    assert_equal(true, highlight_off[6])
    # STRING_END: )
    assert_equal(Face[:string], highlight_on[6])
    assert_equal(true, highlight_off[7])
  end

  def test_prism_highlight_percent_uppper_i
    Window.has_colors = true
    @buffer.insert('%I(x y)')
    @buffer.beginning_of_buffer
    highlight_on, highlight_off = call_highlight
    # PERCENT_UPPER_I: %I(
    assert_equal(Face[:string], highlight_on[0])
    assert_equal(true, highlight_off[3])
    # STRING_CONTENT: x
    assert_equal(Face[:string], highlight_on[3])
    assert_equal(true, highlight_off[4])
    # STRING_CONTENT: y
    assert_equal(Face[:string], highlight_on[5])
    assert_equal(true, highlight_off[6])
    # STRING_END: )
    assert_equal(Face[:string], highlight_on[6])
    assert_equal(true, highlight_off[7])
  end

  def test_prism_highlight_percent_lower_w
    Window.has_colors = true
    @buffer.insert('%w(x y)')
    @buffer.beginning_of_buffer
    highlight_on, highlight_off = call_highlight
    # PERCENT_LOWER_W: %w(
    assert_equal(Face[:string], highlight_on[0])
    assert_equal(true, highlight_off[3])
    # STRING_CONTENT: x
    assert_equal(Face[:string], highlight_on[3])
    assert_equal(true, highlight_off[4])
    # STRING_CONTENT: y
    assert_equal(Face[:string], highlight_on[5])
    assert_equal(true, highlight_off[6])
    # STRING_END: )
    assert_equal(Face[:string], highlight_on[6])
    assert_equal(true, highlight_off[7])
  end

  def test_prism_highlight_percent_uppper_w
    Window.has_colors = true
    @buffer.insert('%W(x y)')
    @buffer.beginning_of_buffer
    highlight_on, highlight_off = call_highlight
    # PERCENT_UPPER_W: %W(
    assert_equal(Face[:string], highlight_on[0])
    assert_equal(true, highlight_off[3])
    # STRING_CONTENT: x
    assert_equal(Face[:string], highlight_on[3])
    assert_equal(true, highlight_off[4])
    # STRING_CONTENT: y
    assert_equal(Face[:string], highlight_on[5])
    assert_equal(true, highlight_off[6])
    # STRING_END: )
    assert_equal(Face[:string], highlight_on[6])
    assert_equal(true, highlight_off[7])
  end

  def test_prism_highlight_percent_lower_x
    Window.has_colors = true
    @buffer.insert('%x(echo hello)')
    @buffer.beginning_of_buffer
    highlight_on, highlight_off = call_highlight
    # PERCENT_LOWER_X: %x(
    assert_equal(Face[:string], highlight_on[0])
    assert_equal(true, highlight_off[3])
    # STRING_CONTENT: echo hello
    assert_equal(Face[:string], highlight_on[3])
    assert_equal(true, highlight_off[13])
    # STRING_END: )
    assert_equal(Face[:string], highlight_on[13])
    assert_equal(true, highlight_off[14])
  end

  def test_prism_highlight_numbers
    Window.has_colors = true
    @buffer.insert("42 + 3.14")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:number], highlight_on[0])   # 42
    assert_equal(Face[:number], highlight_on[5])   # 3.14
  end

  def test_prism_highlight_constants
    Window.has_colors = true
    @buffer.insert("Foo::BAR")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:type], highlight_on[0])  # Foo
    assert_equal(Face[:constant], highlight_on[5])  # BAR
  end

  def test_prism_highlight_constants_non_ascii
    Window.has_colors = true
    @buffer.insert("Πᾶν::ΦΩ͂Σ")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:type], highlight_on[0])  # Πᾶν
    assert_equal(Face[:constant], highlight_on[9])  # ΦΩ͂Σ
  end

  def test_prism_highlight_type_without_lowercase
    Window.has_colors = true
    @buffer.insert("class X")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:type], highlight_on[6])  # X
  end

  def test_prism_highlight_variables
    Window.has_colors = true
    @buffer.insert("@foo + $bar")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:variable], highlight_on[0])  # @foo
    assert_equal(Face[:variable], highlight_on[7])  # $bar
  end

  def test_prism_highlight_operators
    Window.has_colors = true
    @buffer.insert("x + y == z")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:operator], highlight_on[2])  # +
    assert_equal(Face[:operator], highlight_on[6])  # ==
  end

  def test_prism_highlight_builtins
    Window.has_colors = true
    @buffer.insert("self.nil?; true; false")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:builtin], highlight_on[0])   # self
    assert_equal(Face[:builtin], highlight_on[11])  # true
    assert_equal(Face[:builtin], highlight_on[17])  # false
  end

  def test_prism_highlight_labels
    Window.has_colors = true
    @buffer.insert("{ foo: 1 }")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:property], highlight_on[2])  # foo:
  end

  def test_prism_highlight_symbol_with_constant
    Window.has_colors = true
    @buffer.insert(":Foo")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    # Both : and Foo should be :string, not :constant
    assert_equal(Face[:string], highlight_on[0])
    assert_equal(Face[:string], highlight_on[1])
  end

  def test_prism_highlight_def_self_method
    Window.has_colors = true
    @buffer.insert("def self.bar; end")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:keyword], highlight_on[0])        # def
    assert_equal(Face[:builtin], highlight_on[4])         # self
    assert_equal(Face[:function_name], highlight_on[9])  # bar
  end

  def test_prism_highlight_def_with_newline
    Window.has_colors = true
    @buffer.insert("def\n  foo\nend")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:keyword], highlight_on[0])        # def
    assert_equal(Face[:function_name], highlight_on[6])  # foo
  end

  def test_prism_highlight_empty_buffer
    Window.has_colors = true
    @buffer.beginning_of_buffer
    highlight_on, highlight_off = call_highlight
    assert_equal({}, highlight_on)
    assert_equal({}, highlight_off)
  end

  def test_prism_highlight_method_call_with_parens
    Window.has_colors = true
    @buffer.insert("puts(1)")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:function_name], highlight_on[0])  # puts
  end

  def test_prism_highlight_method_call_no_parens
    Window.has_colors = true
    @buffer.insert("puts 1")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:function_name], highlight_on[0])  # puts
  end

  def test_prism_highlight_method_call_with_receiver
    Window.has_colors = true
    @buffer.insert("foo.bar")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:function_name], highlight_on[4])  # bar
  end

  def test_prism_highlight_method_call_without_parens_in_def
    Window.has_colors = true
    @buffer.insert("def foo\n  bar\nend")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:function_name], highlight_on[4])   # foo (after def)
    assert_equal(Face[:function_name], highlight_on[10])  # bar (method call)
  end

  def test_prism_highlight_variable_not_function
    Window.has_colors = true
    @buffer.insert("x = 1\nx")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_nil(highlight_on[6])  # x on second line is a local variable read
  end

  def test_prism_highlight_op_writer_method_call
    Window.has_colors = true
    @buffer.insert("a.foo += 1")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:function_name], highlight_on[0])  # a
    assert_equal(Face[:function_name], highlight_on[2])  # foo
  end

  def test_prism_highlight_and_writer_method_call
    Window.has_colors = true
    @buffer.insert("a.foo &&= 1")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:function_name], highlight_on[0])  # a
    assert_equal(Face[:function_name], highlight_on[2])  # foo
  end

  def test_prism_highlight_or_writer_method_call
    Window.has_colors = true
    @buffer.insert("a.foo ||= 1")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:function_name], highlight_on[0])  # a
    assert_equal(Face[:function_name], highlight_on[2])  # foo
  end

  def test_prism_highlight_type_method_call
    Window.has_colors = true
    @buffer.insert("Foo()")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:type], highlight_on[0])  # Foo
  end

  def test_prism_highlight_constant_method_call
    Window.has_colors = true
    @buffer.insert("FOO()")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:constant], highlight_on[0])  # FOO
  end

  def test_prism_highlight_type_method_call_with_namespace
    Window.has_colors = true
    @buffer.insert("Foo::Bar()")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:type], highlight_on[0])  # Foo
    assert_equal(Face[:type], highlight_on[5])  # Bar
  end

  def test_prism_highlight_constant_method_call_with_namespace
    Window.has_colors = true
    @buffer.insert("Foo::BAR()")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:type], highlight_on[0])  # Foo
    assert_equal(Face[:constant], highlight_on[5])  # BAR
  end

  def test_prism_highlight_type_method_call_with_dot
    Window.has_colors = true
    @buffer.insert("Foo.Bar()")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:type], highlight_on[0])  # Foo
    assert_equal(Face[:function_name], highlight_on[4])  # Bar
  end

  def test_prism_highlight_constant_method_call_with_dot
    Window.has_colors = true
    @buffer.insert("Foo.BAR()")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:type], highlight_on[0])  # Foo
    assert_equal(Face[:function_name], highlight_on[4])  # BAR
  end

  def test_prism_highlight_method_call_non_ascii
    Window.has_colors = true
    @buffer.insert("てすと")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:function_name], highlight_on[0])  # てすと
  end

  def test_prism_highlight_method_call_with_operator
    Window.has_colors = true
    @buffer.insert("a.+(1)")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:function_name], highlight_on[2])  # +
  end

  def test_prism_keyword_method
    Window.has_colors = true
    @buffer.insert("def self.redo")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:function_name], highlight_on[9])  # redo
  end

  def test_prism_keyword_symbol
    Window.has_colors = true
    @buffer.insert(":redo")
    @buffer.beginning_of_buffer
    highlight_on, _ = call_highlight
    assert_equal(Face[:string], highlight_on[0])  # :
    assert_equal(Face[:string], highlight_on[1])  # redo
  end
end
