require_relative "../../test_helper"
require "textbringer/engines/emacs_engine"

class TestEmacsEngine < Textbringer::TestCase
  def test_engine_name
    assert_equal(:emacs, EmacsEngine.engine_name)
  end

  def test_supports_multi_stroke
    assert_equal(true, EmacsEngine.supports_multi_stroke?)
  end

  def test_supports_prefix_arg
    assert_equal(true, EmacsEngine.supports_prefix_arg?)
  end

  def test_supports_keyboard_macros
    assert_equal(true, EmacsEngine.supports_keyboard_macros?)
  end

  def test_selection_model
    assert_equal(:emacs_mark, EmacsEngine.selection_model)
  end

  def test_clipboard_model
    assert_equal(:kill_ring, EmacsEngine.clipboard_model)
  end

  def test_global_keymap
    assert_equal(GLOBAL_MAP, EmacsEngine.global_keymap)
  end

  def test_minibuffer_keymap
    assert_equal(MINIBUFFER_LOCAL_MAP, EmacsEngine.minibuffer_keymap)
  end

  def test_buffer_features
    features = EmacsEngine.buffer_features
    assert(features.include?(:kill_ring))
    assert(features.include?(:mark_ring))
    assert(features.include?(:global_mark_ring))
    assert(features.include?(:input_methods))
  end

  def test_keymap_has_emacs_navigation
    assert_equal(:forward_char, GLOBAL_MAP.lookup(["\C-f"]))
    assert_equal(:backward_char, GLOBAL_MAP.lookup(["\C-b"]))
    assert_equal(:next_line, GLOBAL_MAP.lookup(["\C-n"]))
    assert_equal(:previous_line, GLOBAL_MAP.lookup(["\C-p"]))
    assert_equal(:beginning_of_line, GLOBAL_MAP.lookup(["\C-a"]))
    assert_equal(:end_of_line, GLOBAL_MAP.lookup(["\C-e"]))
  end

  def test_keymap_has_emacs_editing
    assert_equal(:delete_char, GLOBAL_MAP.lookup(["\C-d"]))
    assert_equal(:clipboard_kill_line, GLOBAL_MAP.lookup(["\C-k"]))
    assert_equal(:clipboard_yank, GLOBAL_MAP.lookup(["\C-y"]))
    assert_equal(:set_mark_command, GLOBAL_MAP.lookup(["\C-@"]))
  end

  def test_keymap_has_multi_stroke_bindings
    # C-x is a prefix key
    cx_map = GLOBAL_MAP.lookup(["\C-x"])
    assert(cx_map.is_a?(Keymap))

    # C-x C-f should be find_file
    assert_equal(:find_file, GLOBAL_MAP.lookup(["\C-x", "\C-f"]))
    # C-x C-s should be save_buffer
    assert_equal(:save_buffer, GLOBAL_MAP.lookup(["\C-x", "\C-s"]))
    # C-x C-c should be exit_textbringer (or save_buffers_kill_textbringer)
    result = GLOBAL_MAP.lookup(["\C-x", "\C-c"])
    assert([:exit_textbringer, :save_buffers_kill_textbringer].include?(result))
  end

  def test_keymap_has_search_bindings
    assert_equal(:isearch_forward, GLOBAL_MAP.lookup(["\C-s"]))
    assert_equal(:isearch_backward, GLOBAL_MAP.lookup(["\C-r"]))
  end

  def test_keymap_has_undo
    assert_equal(:undo, GLOBAL_MAP.lookup(["\C-_"]))
  end
end
