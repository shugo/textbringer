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

  def test_indent_line_class
    @c_mode.indent_line
    assert_equal("", @buffer.to_s)
    @buffer.insert(<<EOF)
#include <stdio.h>

int
main()
{
EOF
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
#include <stdio.h>

int
main()
{
    
EOF
    @buffer.insert("if (1) {\n")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
#include <stdio.h>

int
main()
{
    if (1) {
	
EOF
    @buffer.insert("puts(\"foo\");\n}")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
#include <stdio.h>

int
main()
{
    if (1) {
	puts("foo");
    }
EOF
    @buffer.insert("\n")
    @c_mode.indent_line
    @buffer.insert("while (0)\n")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
#include <stdio.h>

int
main()
{
    if (1) {
	puts("foo");
    }
    while (0)
	
EOF
    @buffer.insert(";\n")
    @c_mode.indent_line
    assert_equal(<<EOF.chop, @buffer.to_s)
#include <stdio.h>

int
main()
{
    if (1) {
	puts("foo");
    }
    while (0)
	;
    
EOF
  end
end
