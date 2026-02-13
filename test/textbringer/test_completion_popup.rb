require_relative "../test_helper"

class TestCompletionPopup < Textbringer::TestCase
  def setup
    super
    @popup = CompletionPopup.instance
  end

  def teardown
    @popup.close
    FloatingWindow.close_all_floating
    super
  end

  def test_show_with_items
    items = [
      { label: "foo", insert_text: "foo()", detail: "Method" },
      { label: "bar", insert_text: "bar", detail: "Variable" },
      { label: "baz", insert_text: "baz()", detail: "Function" }
    ]

    @popup.show(items: items, start_point: 0)

    assert(@popup.visible?)
    assert_equal(items, @popup.items)
    assert_equal(0, @popup.selected_index)
    assert_equal(0, @popup.start_point)
  end

  def test_show_with_empty_items
    @popup.show(items: [], start_point: 0)

    refute(@popup.visible?)
    assert_empty(@popup.items)
  end

  def test_hide
    items = [{ label: "foo", insert_text: "foo" }]
    @popup.show(items: items, start_point: 0)

    assert(@popup.visible?)
    @popup.hide
    refute(@popup.visible?)
  end

  def test_close
    items = [{ label: "foo", insert_text: "foo" }]
    @popup.show(items: items, start_point: 0)

    @popup.close
    refute(@popup.visible?)
    assert_empty(@popup.items)
    assert_nil(@popup.start_point)
  end

  def test_select_next
    items = [
      { label: "foo", insert_text: "foo" },
      { label: "bar", insert_text: "bar" },
      { label: "baz", insert_text: "baz" }
    ]
    @popup.show(items: items, start_point: 0)

    assert_equal(0, @popup.selected_index)
    @popup.select_next
    assert_equal(1, @popup.selected_index)
    @popup.select_next
    assert_equal(2, @popup.selected_index)
    @popup.select_next
    assert_equal(0, @popup.selected_index)  # Wraps around
  end

  def test_select_previous
    items = [
      { label: "foo", insert_text: "foo" },
      { label: "bar", insert_text: "bar" },
      { label: "baz", insert_text: "baz" }
    ]
    @popup.show(items: items, start_point: 0)

    assert_equal(0, @popup.selected_index)
    @popup.select_previous
    assert_equal(2, @popup.selected_index)  # Wraps around
    @popup.select_previous
    assert_equal(1, @popup.selected_index)
    @popup.select_previous
    assert_equal(0, @popup.selected_index)
  end

  def test_current_item
    items = [
      { label: "foo", insert_text: "foo" },
      { label: "bar", insert_text: "bar" }
    ]
    @popup.show(items: items, start_point: 0)

    assert_equal({ label: "foo", insert_text: "foo" }, @popup.current_item)
    @popup.select_next
    assert_equal({ label: "bar", insert_text: "bar" }, @popup.current_item)
  end

  def test_current_item_when_empty
    assert_nil(@popup.current_item)
  end

  def test_accept
    items = [
      { label: "foo", insert_text: "foo()" },
      { label: "bar", insert_text: "bar" }
    ]
    @popup.show(items: items, start_point: 0)
    @popup.select_next  # Select "bar"

    item = @popup.accept
    assert_equal({ label: "bar", insert_text: "bar" }, item)
    refute(@popup.visible?)
  end

  def test_accept_when_not_visible
    result = @popup.accept
    assert_nil(result)
  end

  def test_cancel
    items = [{ label: "foo", insert_text: "foo" }]
    @popup.show(items: items, start_point: 0)

    result = @popup.cancel
    assert_nil(result)
    refute(@popup.visible?)
  end

  def test_visible_when_not_shown
    refute(@popup.visible?)
  end

  def test_singleton_instance
    popup1 = CompletionPopup.instance
    popup2 = CompletionPopup.instance
    assert_same(popup1, popup2)
  end

  def test_show_with_prefix
    items = [{ label: "foo", insert_text: "foo" }]
    @popup.show(items: items, start_point: 5, prefix: "fo")

    assert(@popup.visible?)
    assert_equal(5, @popup.start_point)
  end

  def test_items_with_detail
    items = [
      { label: "method_name", insert_text: "method_name()", detail: "String" }
    ]
    @popup.show(items: items, start_point: 0)

    assert(@popup.visible?)
    assert_equal("method_name", @popup.current_item[:label])
    assert_equal("String", @popup.current_item[:detail])
  end

  def test_select_next_when_not_visible
    @popup.select_next
    assert_equal(0, @popup.selected_index)
  end

  def test_select_previous_when_not_visible
    @popup.select_previous
    assert_equal(0, @popup.selected_index)
  end
end
