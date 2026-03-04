require_relative "../../test_helper"

class TestCompiler < Textbringer::TestCase
  def compile(source)
    reader = Textbringer::Elisp::Reader.new(source)
    forms = reader.read_all
    compiler = Textbringer::Elisp::Compiler.new
    compiler.compile(forms)
  end

  def test_integer_literal
    ruby = compile("42")
    assert_match(/42/, ruby)
  end

  def test_string_literal
    ruby = compile('"hello"')
    assert_match(/"hello"/, ruby)
  end

  def test_nil_compiles_to_nil
    ruby = compile("nil")
    assert_match(/\bnil\b/, ruby)
  end

  def test_t_compiles_to_true
    ruby = compile("t")
    assert_match(/\btrue\b/, ruby)
  end

  def test_symbol_ref
    ruby = compile("foo")
    assert_match(/R\.get_var\(:\"foo\"\)/, ruby)
  end

  def test_function_call
    ruby = compile("(my-func 1 2)")
    assert_match(/R\.funcall\(:\"my-func\"/, ruby)
  end

  def test_plus_optimized
    ruby = compile("(+ 1 2)")
    assert_match(/R\.el_plus\(1, 2\)/, ruby)
  end

  def test_defun
    ruby = compile("(defun double (x) (* x 2))")
    assert_match(/R\.defun\(:\"double\"\)/, ruby)
  end

  def test_let
    ruby = compile("(let ((x 1)) x)")
    assert_match(/R\.with_dynamic_bindings/, ruby)
  end

  def test_let_star
    ruby = compile("(let* ((x 1) (y 2)) (+ x y))")
    assert_match(/R\.with_dynamic_binding/, ruby)
  end

  def test_if
    ruby = compile("(if t 1 2)")
    assert_match(/R\.truthy\?/, ruby)
  end

  def test_when
    ruby = compile("(when t 1)")
    assert_match(/R\.truthy\?/, ruby)
  end

  def test_unless
    ruby = compile("(unless nil 1)")
    assert_match(/!R\.truthy\?/, ruby)
  end

  def test_progn
    ruby = compile("(progn 1 2 3)")
    assert_match(/begin/, ruby)
  end

  def test_while
    ruby = compile("(while t nil)")
    assert_match(/while R\.truthy\?/, ruby)
  end

  def test_setq
    ruby = compile("(setq x 42)")
    assert_match(/R\.set_var\(:\"x\", 42\)/, ruby)
  end

  def test_quote_symbol
    ruby = compile("'foo")
    assert_match(/:\"foo\"/, ruby)
  end

  def test_quote_list
    ruby = compile("'(1 2 3)")
    assert_match(/R\.list\(1, 2, 3\)/, ruby)
  end

  def test_lambda
    ruby = compile("(lambda (x) (* x 2))")
    assert_match(/R\.make_lambda/, ruby)
  end

  def test_and
    ruby = compile("(and 1 2)")
    assert_match(/R\.el_and/, ruby)
  end

  def test_or
    ruby = compile("(or 1 2)")
    assert_match(/R\.el_or/, ruby)
  end

  def test_cond
    ruby = compile("(cond ((= x 1) 10) (t 20))")
    assert_match(/if R\.truthy\?/, ruby)
    assert_match(/else/, ruby)
  end

  def test_unwind_protect
    ruby = compile("(unwind-protect (foo) (bar))")
    assert_match(/begin/, ruby)
    assert_match(/ensure/, ruby)
  end

  def test_condition_case
    ruby = compile("(condition-case err (foo) (error (message err)))")
    assert_match(/rescue/, ruby)
  end

  def test_generated_ruby_is_valid
    sources = [
      "(+ 1 2)",
      "(defun f (x) (* x 2))",
      "(let ((x 1)) x)",
      "(if t 1 2)",
      "(progn 1 2 3)",
      "(setq x 42)",
      "'foo",
      "(and 1 2)",
      "(or nil 3)",
      "(lambda (x) x)",
    ]
    sources.each do |src|
      ruby = compile(src)
      # Should parse without syntax error
      assert_nothing_raised("Failed to parse Ruby from: #{src}") do
        RubyVM::InstructionSequence.compile(ruby)
      end
    end
  end
end
