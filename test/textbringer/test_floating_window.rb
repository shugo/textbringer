require_relative "../test_helper"

class TestFloatingWindow < Textbringer::TestCase
  def setup
    super
    @floating_window = nil
  end

  def teardown
    @floating_window&.close
    FloatingWindow.close_all_floating
    super
  end

  def test_initialize
    @floating_window = FloatingWindow.new(5, 30, 10, 20)
    assert_not_nil(@floating_window)
    assert_equal(5, @floating_window.lines)
    assert_equal(30, @floating_window.columns)
    assert_equal(10, @floating_window.y)
    assert_equal(20, @floating_window.x)
    assert_not_nil(@floating_window.buffer)
    assert_match(/\*floating-\d+\*/, @floating_window.buffer.name)
    refute(@floating_window.visible?)
    refute(@floating_window.deleted?)
  end

  def test_initialize_with_custom_buffer
    custom_buffer = Buffer.new_buffer("*test-popup*", undo_limit: 0)
    @floating_window = FloatingWindow.new(5, 30, 10, 20, buffer: custom_buffer)
    assert_equal(custom_buffer, @floating_window.buffer)
    assert_equal("*test-popup*", @floating_window.buffer.name)
  ensure
    custom_buffer.kill if custom_buffer && Buffer[custom_buffer.name]
  end

  def test_at_cursor
    @floating_window = FloatingWindow.at_cursor(lines: 5, columns: 30)
    assert_not_nil(@floating_window)
    assert_equal(5, @floating_window.lines)
    assert_equal(30, @floating_window.columns)
  end

  def test_centered
    @floating_window = FloatingWindow.centered(lines: 10, columns: 40)
    assert_not_nil(@floating_window)
    assert_equal(10, @floating_window.lines)
    assert_equal(40, @floating_window.columns)
    # Check roughly centered (exact values depend on terminal size)
    assert(@floating_window.y >= 0)
    assert(@floating_window.x >= 0)
  end

  def test_floating_window_methods
    @floating_window = FloatingWindow.new(5, 30, 10, 20)
    assert(@floating_window.floating_window?)
    refute(@floating_window.echo_area?)
    refute(@floating_window.active?)  # Not visible yet
  end

  def test_show_and_hide
    @floating_window = FloatingWindow.new(5, 30, 10, 20)
    refute(@floating_window.visible?)
    refute(@floating_window.active?)

    @floating_window.show
    assert(@floating_window.visible?)
    assert(@floating_window.active?)

    @floating_window.hide
    refute(@floating_window.visible?)
    refute(@floating_window.active?)
  end

  def test_close
    @floating_window = FloatingWindow.new(5, 30, 10, 20)
    buffer_name = @floating_window.buffer.name

    @floating_window.close
    assert(@floating_window.deleted?)
    refute(@floating_window.visible?)
    # Auto-generated buffer should be deleted
    assert_nil(Buffer[buffer_name])
  end

  def test_close_preserves_custom_buffer
    custom_buffer = Buffer.new_buffer("*test-popup*", undo_limit: 0)
    @floating_window = FloatingWindow.new(5, 30, 10, 20, buffer: custom_buffer)

    @floating_window.close
    assert(@floating_window.deleted?)
    # Custom buffer should still exist
    assert_not_nil(Buffer["*test-popup*"])
  ensure
    custom_buffer.kill if custom_buffer && Buffer[custom_buffer.name]
  end

  def test_class_level_tracking
    win1 = FloatingWindow.new(5, 30, 10, 20)
    win2 = FloatingWindow.new(5, 30, 15, 25)

    floating_windows = FloatingWindow.floating_windows
    assert_includes(floating_windows, win1)
    assert_includes(floating_windows, win2)

    win1.close
    floating_windows = FloatingWindow.floating_windows
    refute_includes(floating_windows, win1)
    assert_includes(floating_windows, win2)

    win2.close
  end

  def test_close_all_floating
    win1 = FloatingWindow.new(5, 30, 10, 20)
    win2 = FloatingWindow.new(5, 30, 15, 25)

    FloatingWindow.close_all_floating

    assert(win1.deleted?)
    assert(win2.deleted?)
    assert_empty(FloatingWindow.floating_windows)
  end

  def test_move_to
    @floating_window = FloatingWindow.new(5, 30, 10, 20)
    @floating_window.move_to(y: 15, x: 25)

    assert_equal(15, @floating_window.y)
    assert_equal(25, @floating_window.x)
  end

  def test_resize
    @floating_window = FloatingWindow.new(5, 30, 10, 20)
    @floating_window.resize(8, 40)

    assert_equal(8, @floating_window.lines)
    assert_equal(40, @floating_window.columns)
  end

  def test_buffer_content
    @floating_window = FloatingWindow.new(5, 30, 10, 20)
    @floating_window.buffer.insert("Hello, World!\n")
    @floating_window.buffer.insert("Line 2\n")
    @floating_window.buffer.insert("Line 3\n")

    assert_equal("Hello, World!\nLine 2\nLine 3\n", @floating_window.buffer.to_s)
  end

  def test_redisplay_does_not_raise
    @floating_window = FloatingWindow.new(5, 30, 10, 20)
    @floating_window.buffer.insert("Test content\n")
    @floating_window.show

    # Should not raise an error
    assert_nothing_raised do
      @floating_window.redisplay
    end
  end

  def test_redisplay_all_floating
    win1 = FloatingWindow.new(5, 30, 10, 20)
    win2 = FloatingWindow.new(5, 30, 15, 25)
    win1.buffer.insert("Window 1\n")
    win2.buffer.insert("Window 2\n")
    win1.show
    win2.show

    # Should not raise an error
    assert_nothing_raised do
      FloatingWindow.redisplay_all_floating
    end

    win1.close
    win2.close
  end

  def test_show_does_not_change_focus
    # Get the current window before creating floating window
    original_window = Window.current
    original_buffer = Buffer.current

    @floating_window = FloatingWindow.at_cursor(lines: 5, columns: 30)
    @floating_window.buffer.insert("Test content\n")
    @floating_window.show

    # Focus should remain on original window
    assert_equal(original_window, Window.current)
    assert_equal(original_buffer, Buffer.current)
  end

  def test_multiple_show_hide_does_not_change_focus
    original_window = Window.current
    original_buffer = Buffer.current

    @floating_window = FloatingWindow.centered(lines: 5, columns: 30)
    @floating_window.buffer.insert("Test\n")

    # Show and hide multiple times
    3.times do
      @floating_window.show
      assert_equal(original_window, Window.current)
      assert_equal(original_buffer, Buffer.current)

      @floating_window.hide
      assert_equal(original_window, Window.current)
      assert_equal(original_buffer, Buffer.current)
    end
  end

  def test_face_parameter_default
    @floating_window = FloatingWindow.new(5, 30, 10, 20)
    # Should have default face
    assert_equal(:floating_window, @floating_window.instance_variable_get(:@face))
  end

  def test_face_parameter_custom
    @floating_window = FloatingWindow.new(5, 30, 10, 20, face: :region)
    assert_equal(:region, @floating_window.instance_variable_get(:@face))
  end

  def test_face_parameter_nil
    @floating_window = FloatingWindow.new(5, 30, 10, 20, face: nil)
    assert_nil(@floating_window.instance_variable_get(:@face))
  end

  def test_face_parameter_at_cursor
    @floating_window = FloatingWindow.at_cursor(lines: 5, columns: 30, face: :isearch)
    assert_equal(:isearch, @floating_window.instance_variable_get(:@face))
  end

  def test_face_parameter_centered
    @floating_window = FloatingWindow.centered(lines: 5, columns: 30, face: :link)
    assert_equal(:link, @floating_window.instance_variable_get(:@face))
  end

  def test_redisplay_with_face
    @floating_window = FloatingWindow.new(5, 30, 10, 20, face: :floating_window)
    @floating_window.buffer.insert("Test content\n")
    @floating_window.show

    # Should not raise an error
    assert_nothing_raised do
      @floating_window.redisplay
    end
  end

  def test_redisplay_without_face
    @floating_window = FloatingWindow.new(5, 30, 10, 20, face: nil)
    @floating_window.buffer.insert("Test content\n")
    @floating_window.show

    # Should not raise an error even without face
    assert_nothing_raised do
      @floating_window.redisplay
    end
  end
end
