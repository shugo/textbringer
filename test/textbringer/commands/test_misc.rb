require_relative "../../test_helper"

class TestMisc < Textbringer::TestCase
  def test_version
    version
    assert_match(/\ATextbringer #{Textbringer::VERSION}/,
                 Window.echo_area.message)
  end

  def test_exit_textbringer
    mkcdtmpdir do
      find_file("foo.txt")
      insert("foo")
      push_keys("no\n")
      assert_nothing_raised do
        exit_textbringer
      end
      push_keys("yes\n")
      assert_raise(SystemExit) do
        exit_textbringer
      end
    end
  end

  def test_execute_command
    execute_command(:version)
    assert_equal(:version, Controller.current.this_command)
    assert_match(/\ATextbringer #{Textbringer::VERSION}/,
                 Window.echo_area.message)

    assert_raise(EditorError) do
      execute_command(:no_such_command)
    end
  end

  def test_eval_expression
    assert_equal(2, eval_expression("1 + 1"))
    assert_equal("2", Window.echo_area.message)
  end

  def test_eval_buffer
    insert("1 + 1")
    assert_equal(2, eval_buffer)
    assert_equal("2", Window.echo_area.message)
  end

  def test_eval_region
    insert("error\n")
    set_mark_command
    insert("1 + 1")
    assert_equal(2, eval_region)
    assert_equal("2", Window.echo_area.message)
  end

  def test_exit_recursive_edit
    assert_raise(EditorError) do
      exit_recursive_edit
    end
    map = Keymap.new
    map.define_key("q", :exit_recursive_edit)
    set_transient_map(map)
    push_keys("q")
    assert_nothing_raised do
      recursive_edit
    end
  end

  def test_abort_recursive_edit
    assert_raise(EditorError) do
      abort_recursive_edit
    end
    map = Keymap.new
    map.define_key("\C-g", :abort_recursive_edit)
    set_transient_map(map)
    push_keys("\C-g")
    assert_raise(Quit) do
      recursive_edit
    end
  end

  def test_top_level
    assert_throw(TOP_LEVEL_TAG) do
      top_level
    end
  end

  def test_keybaord_quit
    assert_raise(Quit) do
      keyboard_quit
    end
  end

  def test_universal_argument
    universal_argument
    assert_equal([4], Controller.current.prefix_arg)
    assert_equal(UNIVERSAL_ARGUMENT_MAP, Controller.current.overriding_map)
  end

  def test_number_prefix_arg
    Controller.current.current_prefix_arg = 17
    assert_equal(17, number_prefix_arg)
    Controller.current.current_prefix_arg = [8]
    assert_equal(8, number_prefix_arg)
    Controller.current.current_prefix_arg = :-
    assert_equal(-1, number_prefix_arg)
  end

  def test_digit_argument
    Controller.current.last_key = "3"
    digit_argument(nil)
    assert_equal(3, Controller.current.prefix_arg)
    Controller.current.last_key = "7"
    digit_argument(3)
    assert_equal(37, Controller.current.prefix_arg)
    Controller.current.last_key = "2"
    digit_argument(:-)
    assert_equal(-2, Controller.current.prefix_arg)
    Controller.current.last_key = "3"
    digit_argument(-2)
    assert_equal(-23, Controller.current.prefix_arg)
  end

  def test_negative_argument
    negative_argument(nil)
    assert_equal(:-, Controller.current.prefix_arg)
    negative_argument(3)
    assert_equal(-3, Controller.current.prefix_arg)
    negative_argument(:-)
    assert_equal(nil, Controller.current.prefix_arg)
  end

  def test_universal_argument_more
    universal_argument_more(nil)
    assert_equal(nil, Controller.current.prefix_arg)
    universal_argument_more([4])
    assert_equal([16], Controller.current.prefix_arg)
    universal_argument_more(:-)
    assert_equal([-4], Controller.current.prefix_arg)
  end

  def test_shell_execute
    shell_execute("#{ruby_install_name} -e 'p 1 + 1'")
    assert_equal("2\n", Buffer.current.to_s)

    push_keys("\C-g")
    shell_execute("#{ruby_install_name} -e 'sleep'")
    assert_match(/Process \d+ was killed by/, Window.echo_area.message)
  end
end
