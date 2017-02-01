require_relative "../test_helper"

class TestController < Textbringer::TestCase
  def setup
    super
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

  def test_read_char
    def @window.read_char
      "a"
    end
    assert_equal("a", @controller.read_char)
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
end
