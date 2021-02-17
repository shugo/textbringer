require_relative "../test_helper"

class TestInputMethod < Textbringer::TestCase
  class Textbringer::InvalidInputMethod < InputMethod
  end

  class Textbringer::CapitalInputMethod < InputMethod
    def handle_event(event)
      if event.is_a?(String)
        event.upcase
      else
        event
      end
    end
  end

  def test_list
    list = InputMethod.list
    assert(list.include?("invalid"))
    assert(list.include?("capital"))
  end

  def test_find
    assert_instance_of(CapitalInputMethod, InputMethod.find("capital"))
    assert_raise(EditorError) do
      InputMethod.find("no_such_input_method")
    end
  end

  def test_disable
    capital_im = CapitalInputMethod.new
    capital_im.toggle
    assert(capital_im.enabled?)
    capital_im.disable
    assert(!capital_im.enabled?)
  end

  def test_filter_event
    invalid_im = InvalidInputMethod.new
    invalid_im.toggle
    assert_raise(EditorError) do
      invalid_im.filter_event(?x)
    end

    capital_im = CapitalInputMethod.new
    assert_equal(?x, capital_im.filter_event(?x))
    capital_im.toggle
    assert_equal(?\e, capital_im.filter_event(?\e))
    assert_equal(?x, capital_im.filter_event(?x))
    assert_equal(?X, capital_im.filter_event(?x))
    assert_equal(:right, capital_im.filter_event(:right))
  end
end
