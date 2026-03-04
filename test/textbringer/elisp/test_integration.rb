require_relative "../../test_helper"

class TestElispIntegration < Textbringer::TestCase
  setup do
    Textbringer::Elisp.reset!
  end

  def eval_elisp(source)
    Textbringer::Elisp.eval_string(source)
  end

  # --- Phase 1: Basic arithmetic ---

  def test_simple_addition
    assert_equal(3, eval_elisp("(+ 1 2)"))
  end

  def test_nested_arithmetic
    assert_equal(14, eval_elisp("(+ (* 2 3) (- 10 2) 0)"))
  end

  def test_integer_literal
    assert_equal(42, eval_elisp("42"))
  end

  def test_string_literal
    assert_equal("hello", eval_elisp('"hello"'))
  end

  # --- Defun and function calls ---

  def test_defun_and_call
    eval_elisp("(defun double (x) (* x 2))")
    assert_equal(10, eval_elisp("(double 5)"))
  end

  def test_defun_multiple_body_forms
    eval_elisp('(defun add3 (a b c) (+ a b c))')
    assert_equal(6, eval_elisp("(add3 1 2 3)"))
  end

  def test_defun_optional_args
    eval_elisp("(defun greet (&optional name) (if name name \"world\"))")
    assert_equal("world", eval_elisp("(greet)"))
    assert_equal("alice", eval_elisp('(greet "alice")'))
  end

  def test_defun_rest_args
    eval_elisp("(defun sum (&rest nums) (apply '+ nums))")
    assert_equal(10, eval_elisp("(sum 1 2 3 4)"))
  end

  # --- Let bindings ---

  def test_let
    result = eval_elisp("(let ((x 10) (y 20)) (+ x y))")
    assert_equal(30, result)
  end

  def test_let_star
    result = eval_elisp("(let* ((x 5) (y (* x 2))) (+ x y))")
    assert_equal(15, result)
  end

  def test_let_restores_bindings
    eval_elisp("(setq x 1)")
    eval_elisp("(let ((x 99)) x)")
    assert_equal(1, eval_elisp("x"))
  end

  # --- Control flow ---

  def test_if_true
    assert_equal(1, eval_elisp("(if t 1 2)"))
  end

  def test_if_false
    assert_equal(2, eval_elisp("(if nil 1 2)"))
  end

  def test_if_no_else
    assert_nil(eval_elisp("(if nil 1)"))
  end

  def test_when
    assert_equal(42, eval_elisp("(when t 42)"))
    assert_nil(eval_elisp("(when nil 42)"))
  end

  def test_unless
    assert_nil(eval_elisp("(unless t 42)"))
    assert_equal(42, eval_elisp("(unless nil 42)"))
  end

  def test_cond
    eval_elisp("(setq x 2)")
    result = eval_elisp("(cond ((= x 1) 10) ((= x 2) 20) (t 30))")
    assert_equal(20, result)
  end

  def test_progn
    result = eval_elisp("(progn 1 2 3)")
    assert_equal(3, result)
  end

  def test_and
    assert_equal(3, eval_elisp("(and 1 2 3)"))
    assert_nil(eval_elisp("(and 1 nil 3)"))
  end

  def test_or
    assert_equal(1, eval_elisp("(or 1 2)"))
    assert_equal(2, eval_elisp("(or nil 2)"))
    assert_nil(eval_elisp("(or nil nil)"))
  end

  # --- While loop ---

  def test_while
    eval_elisp("(setq x 0)")
    eval_elisp("(setq sum 0)")
    eval_elisp("(while (< x 5) (setq sum (+ sum x)) (setq x (1+ x)))")
    assert_equal(10, eval_elisp("sum"))  # 0+1+2+3+4 = 10
  end

  # --- Setq ---

  def test_setq
    eval_elisp("(setq x 42)")
    assert_equal(42, eval_elisp("x"))
  end

  def test_setq_multiple
    eval_elisp("(setq a 1 b 2)")
    assert_equal(1, eval_elisp("a"))
    assert_equal(2, eval_elisp("b"))
  end

  # --- Quote ---

  def test_quote_symbol
    assert_equal(:"foo", eval_elisp("'foo"))
  end

  def test_quote_list
    result = eval_elisp("'(1 2 3)")
    assert_instance_of(Textbringer::Elisp::Runtime::Cons, result)
    assert_equal([1, 2, 3], result.to_list)
  end

  # --- Lambda ---

  def test_lambda
    result = eval_elisp("(funcall (lambda (x) (* x 3)) 5)")
    assert_equal(15, result)
  end

  # --- Defvar ---

  def test_defvar
    eval_elisp("(defvar my-var 42)")
    assert_equal(42, eval_elisp("my-var"))
  end

  # --- Comparison ---

  def test_eq
    assert_equal(true, eval_elisp("(eq 'foo 'foo)"))
  end

  def test_equal
    assert_equal(true, eval_elisp('(equal "abc" "abc")'))
  end

  # --- List operations ---

  def test_car_cdr
    assert_equal(1, eval_elisp("(car '(1 2 3))"))
    result = eval_elisp("(cdr '(1 2 3))")
    assert_equal([2, 3], result.to_list)
  end

  def test_cons
    result = eval_elisp("(cons 1 '(2 3))")
    assert_equal([1, 2, 3], result.to_list)
  end

  # --- String operations ---

  def test_concat
    assert_equal("foobar", eval_elisp('(concat "foo" "bar")'))
  end

  def test_substring
    assert_equal("llo", eval_elisp('(substring "hello" 2)'))
  end

  # --- Type predicates ---

  def test_null
    assert_equal(true, eval_elisp("(null nil)"))
    assert_nil(eval_elisp("(null 1)"))
  end

  def test_numberp
    assert_equal(true, eval_elisp("(numberp 42)"))
    assert_nil(eval_elisp('(numberp "no")'))
  end

  # --- Error handling ---

  def test_condition_case
    result = eval_elisp('(condition-case err (error "boom") (error 42))')
    assert_equal(42, result)
  end

  # --- Buffer operations ---

  def test_buffer_insert_and_point
    eval_elisp('(insert "hello")')
    assert_equal("hello", Buffer.current.to_s)
    assert_equal(5, eval_elisp("(point)"))
  end

  def test_goto_char
    eval_elisp('(insert "hello")')
    eval_elisp("(goto-char 1)")
    assert_equal(1, eval_elisp("(point)"))
  end

  # --- Multiple top-level forms ---

  def test_multiple_forms
    result = eval_elisp("(setq a 1) (setq b 2) (+ a b)")
    assert_equal(3, result)
  end

  # --- Provide ---

  def test_provide
    eval_elisp("(provide 'my-feature)")
    assert_equal(true, Textbringer::Elisp::Runtime.featurep?(:"my-feature"))
  end

  # --- Feature: prog1 ---

  def test_prog1
    result = eval_elisp("(prog1 1 2 3)")
    assert_equal(1, result)
  end

  # --- Feature: not ---

  def test_not
    assert_equal(true, eval_elisp("(not nil)"))
    assert_nil(eval_elisp("(not t)"))
  end
end
