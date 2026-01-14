require_relative "../../test_helper"
require "textbringer/engines/cua_engine"

class TestCuaEngine < Textbringer::TestCase
  setup do
    CuaEngine.setup
  end

  def test_engine_name
    assert_equal(:cua, CuaEngine.engine_name)
  end

  def test_supports_multi_stroke
    assert_equal(false, CuaEngine.supports_multi_stroke?)
  end

  def test_supports_prefix_arg
    assert_equal(false, CuaEngine.supports_prefix_arg?)
  end

  def test_supports_keyboard_macros
    assert_equal(false, CuaEngine.supports_keyboard_macros?)
  end

  def test_selection_model
    assert_equal(:shift_select, CuaEngine.selection_model)
  end

  def test_clipboard_model
    assert_equal(:simple, CuaEngine.clipboard_model)
  end

  def test_global_keymap
    assert_equal(CUA_MAP, CuaEngine.global_keymap)
  end

  def test_keymap_has_standard_shortcuts
    # Verify standard shortcuts are bound
    assert_equal(:save_buffer, CUA_MAP.lookup(["\C-s"]))
    assert_equal(:find_file, CUA_MAP.lookup(["\C-o"]))
    assert_equal(:undo, CUA_MAP.lookup(["\C-z"]))
    assert_equal(:redo_command, CUA_MAP.lookup(["\C-y"]))
    assert_equal(:cua_copy, CUA_MAP.lookup(["\C-c"]))
    assert_equal(:cua_cut, CUA_MAP.lookup(["\C-x"]))
    assert_equal(:cua_paste, CUA_MAP.lookup(["\C-v"]))
    assert_equal(:cua_select_all, CUA_MAP.lookup(["\C-a"]))
    assert_equal(:isearch_forward, CUA_MAP.lookup(["\C-f"]))
    assert_equal(:exit_textbringer, CUA_MAP.lookup(["\C-q"]))
  end

  def test_keymap_has_navigation_keys
    # CUA navigation commands clear selection when moving
    assert_equal(:cua_forward_char, CUA_MAP.lookup([:right]))
    assert_equal(:cua_backward_char, CUA_MAP.lookup([:left]))
    assert_equal(:cua_previous_line, CUA_MAP.lookup([:up]))
    assert_equal(:cua_next_line, CUA_MAP.lookup([:down]))
    assert_equal(:cua_beginning_of_line, CUA_MAP.lookup([:home]))
    assert_equal(:cua_end_of_line, CUA_MAP.lookup([:end]))
  end

  def test_keymap_has_shift_selection_keys
    assert_equal(:cua_shift_forward_char, CUA_MAP.lookup([:sright]))
    assert_equal(:cua_shift_backward_char, CUA_MAP.lookup([:sleft]))
    assert_equal(:cua_shift_previous_line, CUA_MAP.lookup([:sup]))
    assert_equal(:cua_shift_next_line, CUA_MAP.lookup([:sdown]))
    assert_equal(:cua_shift_beginning_of_line, CUA_MAP.lookup([:shome]))
    assert_equal(:cua_shift_end_of_line, CUA_MAP.lookup([:send]))
  end

  def test_commands_are_defined
    assert(Commands.list.include?(:cua_copy))
    assert(Commands.list.include?(:cua_cut))
    assert(Commands.list.include?(:cua_paste))
    assert(Commands.list.include?(:cua_select_all))
    assert(Commands.list.include?(:cua_new_buffer))
    assert(Commands.list.include?(:cua_shift_forward_char))
    assert(Commands.list.include?(:cua_forward_char))
    assert(Commands.list.include?(:cua_backward_char))
    assert(Commands.list.include?(:cua_next_line))
    assert(Commands.list.include?(:cua_previous_line))
  end

  def test_cua_navigation_clears_selection
    buffer.insert("hello world")
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.forward_char
    buffer.activate_mark

    assert(buffer.mark_active?)

    # Regular navigation should clear selection
    cua_forward_char

    assert_equal(false, buffer.mark_active?)
    assert_equal(2, buffer.point)  # Moved forward
  end

  def test_cua_select_all
    buffer.insert("hello world")
    cua_select_all
    assert(buffer.mark_active?)
    assert_equal(0, buffer.mark)
    assert_equal(11, buffer.point)
  end

  def test_cua_copy_with_selection
    buffer.insert("hello world")
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.forward_word
    buffer.activate_mark

    cua_copy

    assert_equal(false, buffer.mark_active?)
    assert_equal("hello world", buffer.to_s)  # Text unchanged
  end

  def test_cua_copy_without_selection
    buffer.insert("hello world")
    buffer.deactivate_mark

    cua_copy  # Should just show message, no error

    assert_equal("hello world", buffer.to_s)
  end

  def test_cua_cut_with_selection
    buffer.insert("hello world")
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.forward_word
    buffer.activate_mark

    cua_cut

    assert_equal(false, buffer.mark_active?)
    assert_equal(" world", buffer.to_s)  # "hello" was cut
  end

  def test_cua_cut_without_selection
    buffer.insert("hello world")
    buffer.deactivate_mark

    cua_cut  # Should just show message, no error

    assert_equal("hello world", buffer.to_s)
  end

  def test_cua_paste_replaces_selection
    buffer.insert("hello world")
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.forward_word
    buffer.activate_mark

    # First cut to put something in clipboard
    cua_cut
    assert_equal(" world", buffer.to_s)

    # Select " world" and paste
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.end_of_buffer
    buffer.activate_mark

    cua_paste

    # " world" should be replaced with "hello"
    assert_equal("hello", buffer.to_s)
  end

  def test_cua_shift_forward_char_activates_mark
    buffer.insert("hello")
    buffer.beginning_of_buffer

    assert_equal(false, buffer.mark_active?)

    cua_shift_forward_char

    assert(buffer.mark_active?)
    assert_equal(0, buffer.mark)
    assert_equal(1, buffer.point)
  end

  def test_cua_shift_forward_char_extends_selection
    buffer.insert("hello")
    buffer.beginning_of_buffer
    buffer.push_mark
    buffer.activate_mark

    cua_shift_forward_char
    cua_shift_forward_char

    assert(buffer.mark_active?)
    assert_equal(0, buffer.mark)
    assert_equal(2, buffer.point)
  end

  def test_cua_shift_backward_char
    buffer.insert("hello")

    cua_shift_backward_char

    assert(buffer.mark_active?)
    assert_equal(5, buffer.mark)
    assert_equal(4, buffer.point)
  end

  def test_cua_shift_next_line
    buffer.insert("line1\nline2")
    buffer.beginning_of_buffer

    cua_shift_next_line

    assert(buffer.mark_active?)
    assert_equal(0, buffer.mark)
    assert_equal(6, buffer.point)
  end

  def test_cua_shift_previous_line
    buffer.insert("line1\nline2")

    cua_shift_previous_line

    assert(buffer.mark_active?)
    assert_equal(11, buffer.mark)
    assert_equal(5, buffer.point)
  end

  def test_cua_shift_beginning_of_line
    buffer.insert("hello world")

    cua_shift_beginning_of_line

    assert(buffer.mark_active?)
    assert_equal(11, buffer.mark)
    assert_equal(0, buffer.point)
  end

  def test_cua_shift_end_of_line
    buffer.insert("hello world")
    buffer.beginning_of_buffer

    cua_shift_end_of_line

    assert(buffer.mark_active?)
    assert_equal(0, buffer.mark)
    assert_equal(11, buffer.point)
  end

  def test_cua_new_buffer
    old_buffer = Buffer.current
    cua_new_buffer
    assert_not_equal(old_buffer, Buffer.current)
  end
end
