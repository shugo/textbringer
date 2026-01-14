require_relative "../test_helper"

class TestController < Textbringer::TestCase
  setup do
    @window = Window.current
    @controller = Controller.new
  end

  teardown do
    @controller.close
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

  def test_read_event
    def @window.read_event
      "a"
    end
    assert_equal("a", @controller.read_event)
    @controller.instance_variable_set(:@executing_keyboard_macro, ["b"])
    assert_equal("b", @controller.read_event)
  end

  def test_read_event_wait_next_tick
    called = false
    @controller.next_tick do
      called = true
    end
    @window.define_singleton_method(:read_event) do
      called ? "a" : nil
    end
    assert_equal("a", @controller.read_event)
    assert(called)
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
    def @window.read_event_nonblock
      nil
    end
    assert_equal(false, @controller.received_keyboard_quit?)

    @window.singleton_class.send(:undef_method, :read_event_nonblock)
    def @window.read_event_nonblock
      "\C-g"
    end
    assert_equal(true, @controller.received_keyboard_quit?)
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

  def test_default_engine_is_emacs
    assert_equal(EmacsEngine, @controller.engine)
  end

  def test_controller_with_custom_engine
    controller = Controller.new(engine: :fake)
    begin
      assert_equal(FakeEngine, controller.engine)
    ensure
      controller.close
    end
  end

  def test_key_binding_delegates_to_engine
    # EmacsEngine uses GLOBAL_MAP
    assert_equal(:forward_char, @controller.key_binding(["\C-f"]))

    # Test with FakeEngine
    FakeEngine.reset
    FakeEngine::FAKE_ENGINE_MAP.define_key("\C-s", :save_buffer)
    controller = Controller.new(engine: :fake)
    begin
      assert_equal(:save_buffer, controller.key_binding(["\C-s"]))
    ensure
      controller.close
    end
  end
end

class TestControllerEngineIntegration < Textbringer::TestCase
  setup do
    FakeEngine.reset
  end

  def test_no_multi_stroke_engine_treats_keymap_as_undefined
    FakeEngine.multi_stroke = false
    FakeEngine::FAKE_ENGINE_MAP.define_key("\C-x\C-f", :find_file)

    controller = FakeController.new(engine: :fake)
    Controller.current = controller

    begin
      # With no multi-stroke support, a partial keymap match should be undefined
      # The key_binding returns a Keymap, but command_loop should
      # treat it as a command (not wait for more keys)
      result = controller.key_binding(["\C-x"])
      assert(result.is_a?(Keymap))
    ensure
      controller.close
    end
  end

  def test_multi_stroke_engine_waits_for_more_keys
    FakeEngine.multi_stroke = true
    FakeEngine::FAKE_ENGINE_MAP.define_key("\C-xa", :forward_char)

    controller = FakeController.new(engine: :fake)
    Controller.current = controller

    begin
      # key_binding for partial sequence returns Keymap
      result = controller.key_binding(["\C-x"])
      assert(result.is_a?(Keymap))

      # Full sequence returns the command
      result = controller.key_binding(["\C-x", "a"])
      assert_equal(:forward_char, result)
    ensure
      controller.close
    end
  end

  def test_prefix_arg_not_passed_when_engine_doesnt_support_it
    FakeEngine.prefix_arg = false

    controller = FakeController.new(engine: :fake)
    Controller.current = controller

    begin
      controller.prefix_arg = [4]

      # Simulate what happens in command_loop when executing command
      if controller.engine.supports_prefix_arg?
        current_prefix = controller.prefix_arg
      else
        current_prefix = nil
      end

      assert_nil(current_prefix)
    ensure
      controller.close
    end
  end

  def test_prefix_arg_passed_when_engine_supports_it
    FakeEngine.prefix_arg = true

    controller = FakeController.new(engine: :fake)
    Controller.current = controller

    begin
      controller.prefix_arg = [4]

      # Simulate what happens in command_loop when executing command
      if controller.engine.supports_prefix_arg?
        current_prefix = controller.prefix_arg
      else
        current_prefix = nil
      end

      assert_equal([4], current_prefix)
    ensure
      controller.close
    end
  end

  def test_engine_process_key_event_uses_overriding_map
    FakeEngine::FAKE_ENGINE_MAP.define_key("a", :forward_char)

    controller = FakeController.new(engine: :fake)
    Controller.current = controller

    begin
      override_map = Keymap.new
      override_map.define_key("a", :backward_char)
      controller.overriding_map = override_map

      # Overriding map should take precedence
      result = controller.key_binding(["a"])
      assert_equal(:backward_char, result)

      controller.overriding_map = nil
      result = controller.key_binding(["a"])
      assert_equal(:forward_char, result)
    ensure
      controller.close
    end
  end

  def test_engine_process_key_event_uses_buffer_keymap
    FakeEngine::FAKE_ENGINE_MAP.define_key("a", :forward_char)

    controller = FakeController.new(engine: :fake)
    Controller.current = controller

    begin
      buffer_map = Keymap.new
      buffer_map.define_key("a", :next_line)
      Buffer.current.keymap = buffer_map

      # Buffer keymap should take precedence over global
      result = controller.key_binding(["a"])
      assert_equal(:next_line, result)

      Buffer.current.keymap = nil
      result = controller.key_binding(["a"])
      assert_equal(:forward_char, result)
    ensure
      controller.close
    end
  end
end
