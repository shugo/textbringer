require_relative "../../test_helper"
require "tmpdir"

class TestCMode < Textbringer::TestCase
  def setup
    super
    @buffer = Buffer.new_buffer("foo.c")
    @c_mode = CMode.new(@buffer)
    switch_to_buffer(@buffer)
  end

  def test_lex
    source = <<'EOF'.b
int
main(int argc, char **argv)
{
    printf("hello world\n");
    return 0;
}
EOF
    tokens = @c_mode.lex(source)
    assert_equal([[1, 0], :keyword, "int"], tokens.first)
    token = tokens.find { |_, name, | name == :string_literal }
    assert_equal([[4, 11], :string_literal, '"hello world\\n"'], token)
  end

  def test_lex_keywords
    source = <<'EOF'.b
auto  break  case  char  const  continue  default  do  double
else  enum  extern  float  for  goto  if  inline  int  long
register  restrict  return  short  signed  sizeof  static  struct
switch  typedef  union  unsigned  void  volatile  while  _Bool
_Complex  _Imaginary
EOF
    tokens = @c_mode.lex(source)
    expected = source.split(/\s+/)
    actual = tokens.select { |_, name,|
      name == :keyword
    }.map { |_, _, text|
      text
    }
    assert_equal(expected, actual)
  end

  def test_lex_punctuators
    source = <<'EOF'.b
[  ]  (  )  {  }
...  .
++  +=  +
->  --  -=  -
*=  *
/=  /
&&  &=  &
||  |=  |
!=  !
~
==  =
^=  ^
<:  <%  <<=  <<  <=  <
>>=  >>  >=  >
?  ;
:>  :
,  ##  #
%>  %:%:  %:  %=  %
EOF
    tokens = @c_mode.lex(source)
    expected = source.split(/\s+/)
    actual = tokens.select { |_, name,|
      name == :punctuator
    }.map { |_, _, text|
      text
    }
    assert_equal(expected, actual)
  end

  def test_lex_string_literals
    source = <<'EOF'.b
"foo\0\17\177\xE3\x81\x82\u3042\U00029E3D"
EOF
    (line, column), name, text = @c_mode.lex(source).first
    assert_equal(1, line)
    assert_equal(0, column)
    assert_equal(:string_literal, name)
    assert_equal(source.chomp, text)
  end

  def test_lex_wide_string_literals
    source = <<'EOF'.b
L"foo\0\17\177\xE3\x81\x82\u3042\U00029E3D"
EOF
    (line, column), name, text = @c_mode.lex(source).first
    assert_equal(1, line)
    assert_equal(0, column)
    assert_equal(:string_literal, name)
    assert_equal(source.chomp, text)
  end

  def test_lex_identifiers
    source = <<'EOF'.b
foo123
\u3042\U00029E3D
goto_line
あああ
EOF
    tokens = @c_mode.lex(source)
    expected = source.split(/\s+/).take(3)
    actual = tokens.select { |_, name,|
      name == :identifier
    }.map { |_, _, text|
      text
    }
    assert_equal(expected, actual)
  end

  def test_indent_line_brace
    @c_mode.indent_line
    assert_equal("", @buffer.to_s)
    @buffer.insert(<<EOF.chop)
#include <stdio.h>

int
main()
{
foo();
EOF
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
#include <stdio.h>

int
main()
{
    foo();
EOF
    @buffer.insert("\n")
    @c_mode.indent_line
    @buffer.insert("if (1) {\nbar();")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
#include <stdio.h>

int
main()
{
    foo();
    if (1) {
	bar();
EOF
    @buffer.insert("\n}")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
#include <stdio.h>

int
main()
{
    foo();
    if (1) {
	bar();
    }
EOF
    @buffer.insert("\n")
    @c_mode.indent_line
    @buffer.insert("while (0)\nbaz()")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
#include <stdio.h>

int
main()
{
    foo();
    if (1) {
	bar();
    }
    while (0)
	baz()
EOF
    @buffer.insert(";\nquux();")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
#include <stdio.h>

int
main()
{
    foo();
    if (1) {
	bar();
    }
    while (0)
	baz();
    quux();
EOF
  end

  def test_indent_line_paren
    @buffer.insert(<<EOF.chop)
int
main()
{
    foo(x, y,
z
EOF
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
int
main()
{
    foo(x, y,
	z
EOF
  end

  def test_indent_line_labels
    @buffer.insert(<<EOF.chop)
int
main()
{
    switch (x) {
case 0:
EOF
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
int
main()
{
    switch (x) {
    case 0:
EOF
    @buffer.insert("\nfoo();")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
int
main()
{
    switch (x) {
    case 0:
	foo();
EOF
    @buffer.insert("\nbar:")
    @c_mode.indent_line
    @buffer.insert("\nbar();")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
int
main()
{
    switch (x) {
    case 0:
	foo();
      bar:
	bar();
EOF

    @buffer.insert("\ndefault:")
    @c_mode.indent_line
    @buffer.insert("\nbreak;")
    @c_mode.indent_line
    @buffer.insert("\n}")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
int
main()
{
    switch (x) {
    case 0:
	foo();
      bar:
	bar();
    default:
	break;
    }
EOF
  end

  def test_indent_line_top_level
    @buffer.insert(<<EOF.chop)
  foo
bar
EOF
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
  foo
  bar
EOF
  end
  
  def test_indent_line_unmatch
    @buffer.insert(<<EOF.chop)
int main()
{
    if (x) [
    }
foo();
EOF
    assert_raise(EditorError) do
      @c_mode.indent_line
    end
  end
  
  def test_indent_line_comments
    @buffer.insert(<<EOF.chop)
int main()
{
    /* foo */
foo();
EOF
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
int main()
{
    /* foo */
    foo();
EOF

    @buffer.clear
    @buffer.insert(<<EOF.chop)
int main()
{
    /* 
     * foo
foo();
EOF
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
int main()
{
    /* 
     * foo
foo();
EOF

    @buffer.clear
    @buffer.insert(<<EOF.chop)
int main()
{
    // foo
foo();
EOF
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
int main()
{
    // foo
    foo();
EOF

    @buffer.clear
    @buffer.insert(<<EOF.chop)
int main()
{
    // foo\\
bar\\
  baz
foo();
EOF
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
int main()
{
    // foo\\
bar\\
  baz
    foo();
EOF

    @buffer.clear
    @buffer.insert(<<EOF.chop)
int main()
{
    // foo\\
foo();
EOF
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
int main()
{
    // foo\\
foo();
EOF
  end

  def test_compile
    @c_mode.compile("#{ruby_install_name} -e 'puts %<hello world>'")
  end

  def test_symbol_pattern
    assert_match(@c_mode.symbol_pattern, "a")
    assert_match(@c_mode.symbol_pattern, "0")
    assert_not_match(@c_mode.symbol_pattern, "あ")
    assert_match(@c_mode.symbol_pattern, "_")
    assert_not_match(@c_mode.symbol_pattern, "?")
    assert_not_match(@c_mode.symbol_pattern, "!")
    assert_not_match(@c_mode.symbol_pattern, "$")
    assert_not_match(@c_mode.symbol_pattern, "@")
  end

  def test_default_compile_command
    assert_equal("make", @c_mode.default_compile_command)
  end
end
