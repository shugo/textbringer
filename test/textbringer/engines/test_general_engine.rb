require_relative "../../test_helper"
require "textbringer/engines/general_engine"

class TestGeneralEngine < Textbringer::TestCase
  setup do
    GeneralEngine.setup
  end

  def test_engine_name
    assert_equal(:general, GeneralEngine.engine_name)
  end

  def test_supports_multi_stroke
    assert_equal(false, GeneralEngine.supports_multi_stroke?)
  end

  def test_supports_prefix_arg
    assert_equal(false, GeneralEngine.supports_prefix_arg?)
  end

  def test_supports_keyboard_macros
    assert_equal(false, GeneralEngine.supports_keyboard_macros?)
  end

  def test_selection_model
    assert_equal(:shift_select, GeneralEngine.selection_model)
  end

  def test_clipboard_model
    assert_equal(:simple, GeneralEngine.clipboard_model)
  end

  def test_global_keymap
    assert_equal(GENERAL_MAP, GeneralEngine.global_keymap)
  end

  def test_keymap_has_standard_shortcuts
    # Verify standard shortcuts are bound
    assert_equal(:save_buffer, GENERAL_MAP.lookup(["\C-s"]))
    assert_equal(:find_file, GENERAL_MAP.lookup(["\C-o"]))
    assert_equal(:undo, GENERAL_MAP.lookup(["\C-z"]))
    assert_equal(:redo_command, GENERAL_MAP.lookup(["\C-y"]))
    assert_equal(:general_copy, GENERAL_MAP.lookup(["\C-c"]))
    assert_equal(:general_cut, GENERAL_MAP.lookup(["\C-x"]))
    assert_equal(:general_paste, GENERAL_MAP.lookup(["\C-v"]))
    assert_equal(:general_select_all, GENERAL_MAP.lookup(["\C-a"]))
    assert_equal(:isearch_forward, GENERAL_MAP.lookup(["\C-f"]))
    assert_equal(:exit_textbringer, GENERAL_MAP.lookup(["\C-q"]))
  end

  def test_keymap_has_navigation_keys
    assert_equal(:forward_char, GENERAL_MAP.lookup([:right]))
    assert_equal(:backward_char, GENERAL_MAP.lookup([:left]))
    assert_equal(:previous_line, GENERAL_MAP.lookup([:up]))
    assert_equal(:next_line, GENERAL_MAP.lookup([:down]))
    assert_equal(:beginning_of_line, GENERAL_MAP.lookup([:home]))
    assert_equal(:end_of_line, GENERAL_MAP.lookup([:end]))
  end

  def test_keymap_has_shift_selection_keys
    assert_equal(:general_shift_forward_char, GENERAL_MAP.lookup([:sright]))
    assert_equal(:general_shift_backward_char, GENERAL_MAP.lookup([:sleft]))
    assert_equal(:general_shift_previous_line, GENERAL_MAP.lookup([:sup]))
    assert_equal(:general_shift_next_line, GENERAL_MAP.lookup([:sdown]))
    assert_equal(:general_shift_beginning_of_line, GENERAL_MAP.lookup([:shome]))
    assert_equal(:general_shift_end_of_line, GENERAL_MAP.lookup([:send]))
  end

  def test_commands_are_defined
    assert(Commands.list.include?(:general_copy))
    assert(Commands.list.include?(:general_cut))
    assert(Commands.list.include?(:general_paste))
    assert(Commands.list.include?(:general_select_all))
    assert(Commands.list.include?(:general_new_buffer))
    assert(Commands.list.include?(:general_shift_forward_char))
  end

  def test_general_select_all
    buffer.insert("hello world")
    general_select_all
    assert(buffer.mark_active?)
    assert_equal(0, buffer.mark)
    assert_equal(11, buffer.point)
  end

  def test_general_copy_with_selection
    buffer.insert("hello world")
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.forward_word
    buffer.activate_mark

    general_copy

    assert_equal(false, buffer.mark_active?)
    assert_equal("hello world", buffer.to_s)  # Text unchanged
  end

  def test_general_copy_without_selection
    buffer.insert("hello world")
    buffer.deactivate_mark

    general_copy  # Should just show message, no error

    assert_equal("hello world", buffer.to_s)
  end

  def test_general_cut_with_selection
    buffer.insert("hello world")
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.forward_word
    buffer.activate_mark

    general_cut

    assert_equal(false, buffer.mark_active?)
    assert_equal(" world", buffer.to_s)  # "hello" was cut
  end

  def test_general_cut_without_selection
    buffer.insert("hello world")
    buffer.deactivate_mark

    general_cut  # Should just show message, no error

    assert_equal("hello world", buffer.to_s)
  end

  def test_general_paste_replaces_selection
    buffer.insert("hello world")
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.forward_word
    buffer.activate_mark

    # First cut to put something in clipboard
    general_cut
    assert_equal(" world", buffer.to_s)

    # Select " world" and paste
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.end_of_buffer
    buffer.activate_mark

    general_paste

    # " world" should be replaced with "hello"
    assert_equal("hello", buffer.to_s)
  end

  def test_general_shift_forward_char_activates_mark
    buffer.insert("hello")
    buffer.beginning_of_buffer

    assert_equal(false, buffer.mark_active?)

    general_shift_forward_char

    assert(buffer.mark_active?)
    assert_equal(0, buffer.mark)
    assert_equal(1, buffer.point)
  end

  def test_general_shift_forward_char_extends_selection
    buffer.insert("hello")
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.activate_mark

    general_shift_forward_char
    general_shift_forward_char

    assert(buffer.mark_active?)
    assert_equal(0, buffer.mark)
    assert_equal(2, buffer.point)
  end

  def test_general_shift_backward_char
    buffer.insert("hello")

    general_shift_backward_char

    assert(buffer.mark_active?)
    assert_equal(5, buffer.mark)
    assert_equal(4, buffer.point)
  end

  def test_general_shift_next_line
    buffer.insert("line1\nline2")
    buffer.beginning_of_buffer

    general_shift_next_line

    assert(buffer.mark_active?)
    assert_equal(0, buffer.mark)
    assert_equal(6, buffer.point)
  end

  def test_general_shift_previous_line
    buffer.insert("line1\nline2")

    general_shift_previous_line

    assert(buffer.mark_active?)
    assert_equal(11, buffer.mark)
    assert_equal(5, buffer.point)
  end

  def test_general_shift_beginning_of_line
    buffer.insert("hello world")

    general_shift_beginning_of_line

    assert(buffer.mark_active?)
    assert_equal(11, buffer.mark)
    assert_equal(0, buffer.point)
  end

  def test_general_shift_end_of_line
    buffer.insert("hello world")
    buffer.beginning_of_buffer

    general_shift_end_of_line

    assert(buffer.mark_active?)
    assert_equal(0, buffer.mark)
    assert_equal(11, buffer.point)
  end

  def test_general_new_buffer
    old_buffer = Buffer.current
    general_new_buffer
    assert_not_equal(old_buffer, Buffer.current)
  end
end
