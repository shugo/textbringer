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

  def test_global_mark
    assert_raise(EditorError) do
      next_global_mark
    end
    assert_raise(EditorError) do
      previous_global_mark
    end
    buf1 = Buffer.new_buffer("*buf1*")
    buf1.insert("foo\n")
    buf1.push_global_mark
    buf1.insert("bar\n")
    buf2 = Buffer.new_buffer("*buf2*")
    buf2.insert("foo")
    buf2.push_global_mark
    buf2.insert("bar")
    buf3 = Buffer.new_buffer("*buf3*")
    switch_to_buffer(buf3)
    next_global_mark
    assert_equal(buf2, Buffer.current)
    assert_equal(3, Buffer.current.point)
    next_global_mark
    assert_equal(buf1, Buffer.current)
    assert_equal(4, Buffer.current.point)
    next_global_mark
    assert_equal(buf3, Buffer.current)
    assert_equal(0, Buffer.current.point)
    next_global_mark
    assert_equal(buf2, Buffer.current)
    assert_equal(3, Buffer.current.point)
    previous_global_mark
    assert_equal(buf3, Buffer.current)
    assert_equal(0, Buffer.current.point)
    previous_global_mark
    assert_equal(buf1, Buffer.current)
    assert_equal(4, Buffer.current.point)
    previous_global_mark
    assert_equal(buf2, Buffer.current)
    assert_equal(3, Buffer.current.point)
    previous_global_mark
    assert_equal(buf3, Buffer.current)
    assert_equal(0, Buffer.current.point)
    Tempfile.create("buf1") do |f|
      f.close
      buf1.save(f.path)
      buf1.kill
      previous_global_mark
      assert_equal(f.path, Buffer.current.file_name)
      assert_equal(4, Buffer.current.point)
    end
  end

  def test_shell_execute
    shell_execute("#{ruby_install_name} -e 'p 1 + 1'")
    assert_equal("2\n", Buffer.current.to_s)

    omit_on_windows do
      push_keys("\C-g")
      shell_execute("#{ruby_install_name} -e 'sleep'")
      assert_match(/Process \d+ was killed by|Process \d+ exited with status code 1/, Window.echo_area.message)
    end
  end

  def test_grep
    grep("#{ruby_install_name} -e 'p 1 + 1'")
    assert_equal("2\n", Buffer.current.to_s)
    assert_equal("Backtrace", Buffer.current.mode.name)
  end

  def test_what_cursor_position
    insert(" \t\C-lあ")
    beginning_of_buffer
    what_cursor_position
    assert_equal("Char: SPC (U+0020) point=0 of 6 (0%) column=1", Window.echo_area.message)
    forward_char
    what_cursor_position
    assert_equal("Char: TAB (U+0009) point=1 of 6 (16%) column=2", Window.echo_area.message)
    forward_char
    what_cursor_position
    assert_equal("Char: C-l (U+000C) point=2 of 6 (33%) column=3", Window.echo_area.message)
    forward_char
    what_cursor_position
    assert_equal("Char: あ (U+3042) point=3 of 6 (50%) column=4", Window.echo_area.message)
  end
end
