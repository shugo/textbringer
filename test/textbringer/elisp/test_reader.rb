require_relative "../../test_helper"

class TestReader < Textbringer::TestCase
  def read(source)
    Textbringer::Elisp::Reader.new(source).read_all
  end

  def read_one(source)
    Textbringer::Elisp::Reader.new(source).read_form
  end

  # --- Atoms ---

  def test_integer
    node = read_one("42")
    assert_instance_of(Textbringer::Elisp::IntegerLit, node)
    assert_equal(42, node.value)
  end

  def test_negative_integer
    node = read_one("-7")
    assert_instance_of(Textbringer::Elisp::IntegerLit, node)
    assert_equal(-7, node.value)
  end

  def test_float
    node = read_one("3.14")
    assert_instance_of(Textbringer::Elisp::FloatLit, node)
    assert_in_delta(3.14, node.value)
  end

  def test_float_exponent
    node = read_one("1e10")
    assert_instance_of(Textbringer::Elisp::FloatLit, node)
    assert_in_delta(1e10, node.value)
  end

  def test_string
    node = read_one('"hello world"')
    assert_instance_of(Textbringer::Elisp::StringLit, node)
    assert_equal("hello world", node.value)
  end

  def test_string_escapes
    node = read_one('"hello\\nworld"')
    assert_instance_of(Textbringer::Elisp::StringLit, node)
    assert_equal("hello\nworld", node.value)
  end

  def test_symbol
    node = read_one("foo-bar")
    assert_instance_of(Textbringer::Elisp::Symbol, node)
    assert_equal("foo-bar", node.name)
  end

  def test_nil_symbol
    node = read_one("nil")
    assert_instance_of(Textbringer::Elisp::Symbol, node)
    assert_equal("nil", node.name)
  end

  def test_t_symbol
    node = read_one("t")
    assert_instance_of(Textbringer::Elisp::Symbol, node)
    assert_equal("t", node.name)
  end

  # --- Characters ---

  def test_character
    node = read_one("?a")
    assert_instance_of(Textbringer::Elisp::CharLit, node)
    assert_equal(97, node.value)
  end

  def test_character_escape
    node = read_one("?\\n")
    assert_instance_of(Textbringer::Elisp::CharLit, node)
    assert_equal(10, node.value)
  end

  def test_control_character
    node = read_one("?\\C-a")
    assert_instance_of(Textbringer::Elisp::CharLit, node)
    assert_equal(1, node.value)
  end

  # --- Lists ---

  def test_empty_list
    node = read_one("()")
    assert_instance_of(Textbringer::Elisp::List, node)
    assert_equal([], node.elements)
    assert_nil(node.dotted)
  end

  def test_simple_list
    node = read_one("(+ 1 2)")
    assert_instance_of(Textbringer::Elisp::List, node)
    assert_equal(3, node.elements.length)
    assert_equal("+", node.elements[0].name)
    assert_equal(1, node.elements[1].value)
    assert_equal(2, node.elements[2].value)
  end

  def test_dotted_pair
    node = read_one("(a . b)")
    assert_instance_of(Textbringer::Elisp::List, node)
    assert_equal(1, node.elements.length)
    assert_equal("a", node.elements[0].name)
    assert_equal("b", node.dotted.name)
  end

  def test_nested_lists
    node = read_one("(a (b c) d)")
    assert_instance_of(Textbringer::Elisp::List, node)
    assert_equal(3, node.elements.length)
    assert_instance_of(Textbringer::Elisp::List, node.elements[1])
    assert_equal(2, node.elements[1].elements.length)
  end

  # --- Quotes ---

  def test_quote
    node = read_one("'foo")
    assert_instance_of(Textbringer::Elisp::Quoted, node)
    assert_equal(:quote, node.kind)
    assert_equal("foo", node.form.name)
  end

  def test_backquote
    node = read_one("`foo")
    assert_instance_of(Textbringer::Elisp::Quoted, node)
    assert_equal(:backquote, node.kind)
  end

  def test_unquote
    node = read_one(",foo")
    assert_instance_of(Textbringer::Elisp::Unquote, node)
    assert_equal(false, node.splicing)
  end

  def test_splice
    node = read_one(",@foo")
    assert_instance_of(Textbringer::Elisp::Unquote, node)
    assert_equal(true, node.splicing)
  end

  def test_function_quote
    node = read_one("#'foo")
    assert_instance_of(Textbringer::Elisp::Quoted, node)
    assert_equal(:function, node.kind)
  end

  # --- Vectors ---

  def test_vector
    node = read_one("[1 2 3]")
    assert_instance_of(Textbringer::Elisp::Vector, node)
    assert_equal(3, node.elements.length)
  end

  # --- Comments ---

  def test_comments_skipped
    forms = read("; this is a comment\n42")
    assert_equal(1, forms.length)
    assert_equal(42, forms[0].value)
  end

  # --- Multiple forms ---

  def test_read_all
    forms = read("1 2 3")
    assert_equal(3, forms.length)
  end

  # --- Errors ---

  def test_unterminated_list
    assert_raise(Textbringer::Elisp::Reader::ReadError) do
      read("(a b")
    end
  end

  def test_unterminated_string
    assert_raise(Textbringer::Elisp::Reader::ReadError) do
      read('"hello')
    end
  end

  def test_unexpected_close_paren
    assert_raise(Textbringer::Elisp::Reader::ReadError) do
      read_one(")")
    end
  end
end
