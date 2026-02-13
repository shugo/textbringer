require_relative "../../test_helper"

class TestCompletionCommands < Textbringer::TestCase
  def setup
    super
    @popup = CompletionPopup.instance
    COMPLETION_POPUP_STATUS[:active] = false
    COMPLETION_POPUP_STATUS[:start_point] = nil
  end

  def teardown
    @popup.close
    FloatingWindow.close_all_floating
    Controller.current.overriding_map = nil
    COMPLETION_POPUP_STATUS[:active] = false
    COMPLETION_POPUP_STATUS[:start_point] = nil
    super
  end

  def test_completion_popup_mode_active
    refute(Commands.completion_popup_mode_active?)

    items = [{ label: "foo", insert_text: "foo" }]
    completion_popup_start(items: items, start_point: 0)

    assert(Commands.completion_popup_mode_active?)
  end

  def test_completion_popup_start
    items = [
      { label: "foo", insert_text: "foo()" },
      { label: "bar", insert_text: "bar" }
    ]
    completion_popup_start(items: items, start_point: 5, prefix: "fo")

    assert(@popup.visible?)
    assert_equal(COMPLETION_POPUP_MAP, Controller.current.overriding_map)
    assert(COMPLETION_POPUP_STATUS[:active])
    assert_equal(5, COMPLETION_POPUP_STATUS[:start_point])
  end

  def test_completion_popup_start_with_empty_items
    completion_popup_start(items: [], start_point: 0)

    refute(@popup.visible?)
    refute(COMPLETION_POPUP_STATUS[:active])
  end

  def test_completion_popup_next
    items = [
      { label: "foo", insert_text: "foo" },
      { label: "bar", insert_text: "bar" }
    ]
    completion_popup_start(items: items, start_point: 0)

    assert_equal(0, @popup.selected_index)
    completion_popup_next
    assert_equal(1, @popup.selected_index)
  end

  def test_completion_popup_previous
    items = [
      { label: "foo", insert_text: "foo" },
      { label: "bar", insert_text: "bar" }
    ]
    completion_popup_start(items: items, start_point: 0)

    assert_equal(0, @popup.selected_index)
    completion_popup_previous
    assert_equal(1, @popup.selected_index)  # Wraps around
  end

  def test_completion_popup_cancel
    items = [{ label: "foo", insert_text: "foo" }]
    completion_popup_start(items: items, start_point: 0)

    assert(@popup.visible?)
    completion_popup_cancel

    refute(@popup.visible?)
    refute(COMPLETION_POPUP_STATUS[:active])
    assert_nil(Controller.current.overriding_map)
  end

  def test_completion_popup_accept_inserts_completion
    buffer.insert("fo")
    start_point = 0

    items = [
      { label: "foo", insert_text: "foo()" },
      { label: "bar", insert_text: "bar" }
    ]
    completion_popup_start(items: items, start_point: start_point)

    # Accept the first item
    completion_popup_accept

    refute(@popup.visible?)
    assert_equal("foo()", buffer.to_s)
    assert_equal(5, buffer.point)
  end

  def test_completion_popup_accept_with_selection
    buffer.insert("b")
    start_point = 0

    items = [
      { label: "foo", insert_text: "foo" },
      { label: "bar", insert_text: "bar()" }
    ]
    completion_popup_start(items: items, start_point: start_point)
    completion_popup_next  # Select "bar"

    completion_popup_accept

    assert_equal("bar()", buffer.to_s)
  end

  def test_completion_popup_done
    items = [{ label: "foo", insert_text: "foo" }]
    completion_popup_start(items: items, start_point: 0)

    assert(COMPLETION_POPUP_STATUS[:active])
    completion_popup_done

    refute(COMPLETION_POPUP_STATUS[:active])
    assert_nil(COMPLETION_POPUP_STATUS[:start_point])
    assert_nil(Controller.current.overriding_map)
  end

  def test_insert_completion_replaces_prefix
    buffer.insert("meth")
    buffer.goto_char(4)
    start_point = 0
    COMPLETION_POPUP_STATUS[:start_point] = start_point

    item = { label: "method_name", insert_text: "method_name()" }
    insert_completion(item)

    assert_equal("method_name()", buffer.to_s)
  end

  def test_insert_completion_uses_label_as_fallback
    buffer.insert("foo")
    COMPLETION_POPUP_STATUS[:start_point] = 0

    item = { label: "foobar" }  # No insert_text
    insert_completion(item)

    assert_equal("foobar", buffer.to_s)
  end

  def test_keymap_definitions
    # Check that the keymap has expected bindings
    assert_equal(:completion_popup_next, COMPLETION_POPUP_MAP.lookup(["\C-n"]))
    assert_equal(:completion_popup_previous, COMPLETION_POPUP_MAP.lookup(["\C-p"]))
    assert_equal(:completion_popup_accept, COMPLETION_POPUP_MAP.lookup(["\C-m"]))
    assert_equal(:completion_popup_accept, COMPLETION_POPUP_MAP.lookup(["\t"]))
    assert_equal(:completion_popup_cancel, COMPLETION_POPUP_MAP.lookup(["\C-g"]))
    assert_equal(:completion_popup_next, COMPLETION_POPUP_MAP.lookup([:down]))
    assert_equal(:completion_popup_previous, COMPLETION_POPUP_MAP.lookup([:up]))
  end
end
