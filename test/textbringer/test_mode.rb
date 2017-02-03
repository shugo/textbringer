require_relative "../test_helper"

class TestMode < Textbringer::TestCase
  class FooMode < Mode
    define_generic_command :foo
  end

  class BarMode < FooMode
    def foo
      :ok
    end
  end

  class BazMode < FooMode
    def foo
      self.no_such_method
    end
  end
  
  def test_generic_command
    foo_mode
    assert_raise(EditorError) do
      foo_command
    end

    bar_mode
    assert_equal(:ok, foo_command)

    baz_mode
    assert_raise(NoMethodError) do
      foo_command
    end
  end
end
