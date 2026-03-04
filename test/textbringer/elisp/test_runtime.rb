require_relative "../../test_helper"

class TestRuntime < Textbringer::TestCase
  R = Textbringer::Elisp::Runtime

  setup do
    R.reset!
  end

  # --- Dynamic binding ---

  def test_get_set_var
    R.set_var(:x, 42)
    assert_equal(42, R.get_var(:x))
  end

  def test_unset_var_returns_nil
    assert_nil(R.get_var(:nonexistent))
  end

  def test_with_dynamic_bindings
    R.set_var(:x, 1)
    R.with_dynamic_bindings({ x: 10 }) do
      assert_equal(10, R.get_var(:x))
      R.set_var(:x, 20)
      assert_equal(20, R.get_var(:x))
    end
    assert_equal(1, R.get_var(:x))
  end

  def test_defvar
    R.defvar(:myvar, 99)
    assert_equal(99, R.get_var(:myvar))
    # defvar should not overwrite existing value
    R.defvar(:myvar, 100)
    assert_equal(99, R.get_var(:myvar))
  end

  # --- Function registry ---

  def test_defun_and_funcall
    R.defun(:double) { |x| x * 2 }
    assert_equal(10, R.funcall(:double, 5))
  end

  def test_funcall_unknown_raises
    assert_raise(R::ElispError) do
      R.funcall(:nonexistent)
    end
  end

  def test_function_ref
    R.defun(:myfn) { 42 }
    ref = R.function_ref(:myfn)
    assert_instance_of(Proc, ref)
    assert_equal(42, ref.call)
  end

  def test_make_lambda
    lam = R.make_lambda { |x| x + 1 }
    assert_instance_of(Proc, lam)
    assert_equal(6, lam.call(5))
  end

  # --- Truthiness ---

  def test_truthy
    assert_equal(true, R.truthy?(true))
    assert_equal(true, R.truthy?(1))
    assert_equal(true, R.truthy?(""))
    assert_equal(true, R.truthy?(0))
    assert_equal(false, R.truthy?(nil))
    assert_equal(false, R.truthy?(false))
  end

  # --- Cons / List ---

  def test_cons
    c = R.cons(1, 2)
    assert_instance_of(R::Cons, c)
    assert_equal(1, R.car(c))
    assert_equal(2, R.cdr(c))
  end

  def test_list
    l = R.list(1, 2, 3)
    assert_instance_of(R::Cons, l)
    assert_equal([1, 2, 3], l.to_list)
  end

  def test_car_cdr_nil
    assert_nil(R.car(nil))
    assert_nil(R.cdr(nil))
  end

  def test_el_length
    assert_equal(0, R.el_length(nil))
    assert_equal(3, R.el_length(R.list(1, 2, 3)))
    assert_equal(5, R.el_length("hello"))
  end

  def test_el_nth
    l = R.list(10, 20, 30)
    assert_equal(10, R.el_nth(0, l))
    assert_equal(20, R.el_nth(1, l))
    assert_equal(30, R.el_nth(2, l))
    assert_nil(R.el_nth(5, l))
  end

  def test_el_append
    a = R.list(1, 2)
    b = R.list(3, 4)
    result = R.el_append(a, b)
    assert_equal([1, 2, 3, 4], result.to_list)
  end

  def test_el_reverse
    l = R.list(1, 2, 3)
    r = R.el_reverse(l)
    assert_equal([3, 2, 1], r.to_list)
  end

  # --- Short-circuit logic ---

  def test_el_and
    assert_equal(3, R.el_and(-> { 1 }, -> { 2 }, -> { 3 }))
    assert_nil(R.el_and(-> { 1 }, -> { nil }, -> { 3 }))
  end

  def test_el_or
    assert_equal(1, R.el_or(-> { 1 }, -> { 2 }))
    assert_equal(2, R.el_or(-> { nil }, -> { 2 }))
    assert_nil(R.el_or(-> { nil }, -> { nil }))
  end

  # --- Arithmetic helpers ---

  def test_el_plus
    assert_equal(10, R.el_plus(1, 2, 3, 4))
    assert_equal(0, R.el_plus)
  end

  def test_el_minus
    assert_equal(-5, R.el_minus(5))
    assert_equal(3, R.el_minus(10, 4, 3))
  end

  def test_el_multiply
    assert_equal(24, R.el_multiply(2, 3, 4))
  end

  def test_el_divide
    assert_equal(5, R.el_divide(10, 2))
  end

  # --- Feature system ---

  def test_provide_and_featurep
    assert_nil(R.featurep?(:myfeat))
    R.provide(:myfeat)
    assert_equal(true, R.featurep?(:myfeat))
  end

  # --- Comparison helpers ---

  def test_el_eq
    assert_equal(true, R.el_eq(1, 1))
    assert_nil(R.el_eq("a", "b"))
  end

  def test_el_not
    assert_equal(true, R.el_not(nil))
    assert_nil(R.el_not(42))
  end
end
