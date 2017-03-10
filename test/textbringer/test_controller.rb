require_relative "../test_helper"

class TestController < Textbringer::TestCase
  setup do
    @window = Window.current
    @controller = Controller.new
  end

  def test_undefined_key
    push_keys "\C-x\C-a\n"
    map = Keymap.new
    map.define_key("\n", :exit_recursive_edit)
    set_transient_map(map)
    recursive_edit
    assert_match(/^C-x C-a is undefined\n\z/, Buffer["*Messages*"].to_s)
  end

  def test_clear_prefix_arg
    echo_area = Window.echo_area
    def echo_area.wait_input(msecs)
      nil
    end

    push_keys "\C-u\C-g"
    recursive_edit
    assert_match(/^Quit\n\z/, Buffer["*Messages*"].to_s)
    assert_equal(nil, @controller.prefix_arg)

    push_keys "\C-u\C-x\C-ma"
    recursive_edit
    assert_match(/^C-x RET a is undefined\n\z/, Buffer["*Messages*"].to_s)
    assert_equal(nil, @controller.prefix_arg)
  end

  def test_read_char
    def @window.read_char
      "a"
    end
    assert_equal("a", @controller.read_char)
    @controller.instance_variable_set(:@executing_keyboard_macro, ["b"])
    assert_equal("b", @controller.read_char)
  end

  def test_wait_input
    def @window.wait_input(msecs)
      "a"
    end
    assert_equal("a", @controller.wait_input(1000))
    @controller.instance_variable_set(:@executing_keyboard_macro, ["b"])
    assert_equal("b", @controller.wait_input(1000))
  end

  def test_received_keyboard_quit?
    def @window.read_char_nonblock
      nil
    end
    assert_equal(false, @controller.received_keyboard_quit?)

    @window.singleton_class.send(:undef_method, :read_char_nonblock)
    def @window.read_char_nonblock
      "\C-g"
    end
    assert_equal(true, @controller.received_keyboard_quit?)
  end

  def test_key_name
    assert_equal("<f1>", @controller.key_name(:f1))
    assert_equal("ESC", @controller.key_name("\e"))
    assert_equal("C-x", @controller.key_name("\C-x"))
    assert_equal("x", @controller.key_name("x"))
    assert_equal("あ", @controller.key_name("あ"))
  end

  def test_echo_input
    @controller.prefix_arg = [4]
    @controller.echo_input
    assert_equal("C-u-", Window.echo_area.message)
    @controller.prefix_arg = [16]
    @controller.echo_input
    assert_equal("C-u([16])-", Window.echo_area.message)
    @controller.prefix_arg = 123
    @controller.echo_input
    assert_equal("C-u(123)-", Window.echo_area.message)
    @controller.prefix_arg = nil
    @controller.key_sequence.replace(["\C-x"])
    @controller.echo_input
    assert_equal("C-x-", Window.echo_area.message)
    @controller.key_sequence.replace(["\C-x", "\C-m"])
    @controller.echo_input
    assert_equal("C-x RET-", Window.echo_area.message)
  end

  def test_clear_message_if_echo_area_is_active
    map = Keymap.new
    map.define_key("a", -> { raise "error" })
    push_keys "a"
    read_from_minibuffer("", keymap: map)
    assert_equal(nil, Window.echo_area.message)
  end
end
