require_relative "../test_helper"

class TestInputMethod < Textbringer::TestCase
  class InvalidInputMethod < InputMethod
  end

  class CapitalInputMethod < InputMethod
    def handle_event(event)
      if event.is_a?(String)
        event.upcase
      else
        event
      end
    end
  end

  def test_filter_event
    invalid_im = InvalidInputMethod.new
    invalid_im.toggle
    assert_raise(EditorError) do
      invalid_im.filter_event(?x)
    end

    capital_im = CapitalInputMethod.new
    capital_im.toggle
    assert_equal(?\e, capital_im.filter_event(?\e))
    assert_equal(?x, capital_im.filter_event(?x))
    assert_equal(?X, capital_im.filter_event(?x))
    assert_equal(:right, capital_im.filter_event(:right))
  end
end
