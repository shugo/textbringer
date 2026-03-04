require_relative "../../test_helper"

class TestPrimitives < Textbringer::TestCase
  R = Textbringer::Elisp::Runtime

  setup do
    Textbringer::Elisp.reset!
    Textbringer::Elisp.init
  end

  # --- Arithmetic ---

  def test_plus
    assert_equal(6, R.funcall(:"+", 1, 2, 3))
  end

  def test_minus
    assert_equal(4, R.funcall(:"-", 10, 3, 3))
    assert_equal(-5, R.funcall(:"-", 5))
  end

  def test_multiply
    assert_equal(24, R.funcall(:"*", 2, 3, 4))
  end

  def test_divide
    assert_equal(5, R.funcall(:"/", 10, 2))
  end

  def test_mod
    assert_equal(1, R.funcall(:"%", 10, 3))
  end

  def test_one_plus
    assert_equal(6, R.funcall(:"1+", 5))
  end

  def test_one_minus
    assert_equal(4, R.funcall(:"1-", 5))
  end

  def test_max
    assert_equal(10, R.funcall(:"max", 3, 10, 5))
  end

  def test_min
    assert_equal(3, R.funcall(:"min", 3, 10, 5))
  end

  def test_abs
    assert_equal(5, R.funcall(:"abs", -5))
  end

  # --- Comparison ---

  def test_num_eq
    assert_equal(true, R.funcall(:"=", 5, 5))
    assert_nil(R.funcall(:"=", 5, 6))
  end

  def test_num_neq
    assert_equal(true, R.funcall(:"/=", 5, 6))
    assert_nil(R.funcall(:"/=", 5, 5))
  end

  def test_lt
    assert_equal(true, R.funcall(:"<", 1, 2))
    assert_nil(R.funcall(:"<", 2, 1))
  end

  # --- List operations ---

  def test_car_cdr
    l = R.list(1, 2, 3)
    assert_equal(1, R.funcall(:"car", l))
    assert_equal([2, 3], R.funcall(:"cdr", l).to_list)
  end

  def test_cons
    c = R.funcall(:"cons", 1, 2)
    assert_equal(1, R.funcall(:"car", c))
    assert_equal(2, R.funcall(:"cdr", c))
  end

  def test_list
    l = R.funcall(:"list", 1, 2, 3)
    assert_equal([1, 2, 3], l.to_list)
  end

  def test_length
    assert_equal(3, R.funcall(:"length", R.list(1, 2, 3)))
    assert_equal(0, R.funcall(:"length", nil))
    assert_equal(5, R.funcall(:"length", "hello"))
  end

  def test_nth
    l = R.list(10, 20, 30)
    assert_equal(20, R.funcall(:"nth", 1, l))
  end

  def test_reverse
    l = R.list(1, 2, 3)
    r = R.funcall(:"reverse", l)
    assert_equal([3, 2, 1], r.to_list)
  end

  def test_append
    a = R.list(1, 2)
    b = R.list(3, 4)
    result = R.funcall(:"append", a, b)
    assert_equal([1, 2, 3, 4], result.to_list)
  end

  def test_member
    l = R.list(1, 2, 3)
    result = R.funcall(:"member", 2, l)
    assert_equal([2, 3], result.to_list)
    assert_nil(R.funcall(:"member", 5, l))
  end

  def test_assoc
    alist = R.list(R.cons(:a, 1), R.cons(:b, 2))
    result = R.funcall(:"assoc", :a, alist)
    assert_equal(:a, R.funcall(:"car", result))
    assert_equal(1, R.funcall(:"cdr", result))
    assert_nil(R.funcall(:"assoc", :c, alist))
  end

  def test_mapcar
    l = R.list(1, 2, 3)
    R.defun(:"my-inc") { |x| x + 1 }
    result = R.funcall(:"mapcar", :"my-inc", l)
    assert_equal([2, 3, 4], result.to_list)
  end

  # --- String operations ---

  def test_concat
    assert_equal("foobar", R.funcall(:"concat", "foo", "bar"))
  end

  def test_substring
    assert_equal("llo", R.funcall(:"substring", "hello", 2))
    assert_equal("ll", R.funcall(:"substring", "hello", 2, 4))
  end

  def test_upcase_downcase
    assert_equal("HELLO", R.funcall(:"upcase", "hello"))
    assert_equal("hello", R.funcall(:"downcase", "HELLO"))
  end

  def test_number_to_string
    assert_equal("42", R.funcall(:"number-to-string", 42))
  end

  def test_string_to_number
    assert_equal(42, R.funcall(:"string-to-number", "42"))
  end

  def test_symbol_name
    assert_equal("foo", R.funcall(:"symbol-name", :foo))
  end

  def test_intern
    assert_equal(:foo, R.funcall(:"intern", "foo"))
  end

  # --- Type predicates ---

  def test_null
    assert_equal(true, R.funcall(:"null", nil))
    assert_nil(R.funcall(:"null", 1))
  end

  def test_listp
    assert_equal(true, R.funcall(:"listp", nil))
    assert_equal(true, R.funcall(:"listp", R.list(1)))
    assert_nil(R.funcall(:"listp", 1))
  end

  def test_consp
    assert_equal(true, R.funcall(:"consp", R.list(1)))
    assert_nil(R.funcall(:"consp", nil))
  end

  def test_atom
    assert_equal(true, R.funcall(:"atom", 1))
    assert_equal(true, R.funcall(:"atom", nil))
    assert_nil(R.funcall(:"atom", R.list(1)))
  end

  def test_stringp
    assert_equal(true, R.funcall(:"stringp", "hello"))
    assert_nil(R.funcall(:"stringp", 1))
  end

  def test_numberp
    assert_equal(true, R.funcall(:"numberp", 42))
    assert_equal(true, R.funcall(:"numberp", 3.14))
    assert_nil(R.funcall(:"numberp", "no"))
  end

  def test_integerp
    assert_equal(true, R.funcall(:"integerp", 42))
    assert_nil(R.funcall(:"integerp", 3.14))
  end

  def test_floatp
    assert_equal(true, R.funcall(:"floatp", 3.14))
    assert_nil(R.funcall(:"floatp", 42))
  end

  def test_symbolp
    assert_equal(true, R.funcall(:"symbolp", :foo))
    assert_nil(R.funcall(:"symbolp", "foo"))
  end

  def test_functionp
    assert_equal(true, R.funcall(:"functionp", -> { 1 }))
    assert_nil(R.funcall(:"functionp", 1))
  end

  def test_not
    assert_equal(true, R.funcall(:"not", nil))
    assert_nil(R.funcall(:"not", 1))
  end

  # --- Misc ---

  def test_apply
    result = R.funcall(:"apply", :"+", R.list(1, 2, 3))
    assert_equal(6, result)
  end

  def test_provide_require
    R.funcall(:"provide", :myfeat)
    assert_equal(true, R.funcall(:"featurep", :myfeat))
  end
end
