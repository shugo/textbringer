require_relative "../test_helper"

class TestFace < Textbringer::TestCase
  def test_define
    foo = Face.define(:foo, foreground: "yellow")
    assert_equal(foo, Face[:foo])
    assert_equal(0, foo.attributes & Curses::A_BOLD)
    assert_equal(0, foo.attributes & Curses::A_UNDERLINE)
    bar = Face.define(:bar, foreground: "red", bold: true)
    assert_equal(bar, Face[:bar])
    assert_equal(Curses::A_BOLD, bar.attributes & Curses::A_BOLD)
    assert_equal(0, bar.attributes & Curses::A_UNDERLINE)
    bar2 = Face.define(:bar, foreground: "green", underline: true)
    assert_same(bar, bar2)
    assert_equal(bar, Face[:bar])
    assert_equal(0, bar.attributes & Curses::A_BOLD)
    assert_equal(Curses::A_UNDERLINE, bar.attributes & Curses::A_UNDERLINE)
  ensure
    Face.delete(:foo)
    Face.delete(:bar)
  end

  def test_inherit_colors
    parent = Face.define(:parent_face, foreground: "red", background: "blue")
    child = Face.define(:child_face, inherit: :parent_face)
    # Child inherits same colors as parent — they share the same color pair slot
    assert_equal(parent.color_pair, child.color_pair)
    assert_equal("red", child.instance_variable_get(:@foreground))
    assert_equal("blue", child.instance_variable_get(:@background))
  ensure
    Face.delete(:parent_face)
    Face.delete(:child_face)
  end

  def test_color_pair_cache_shared_for_same_colors
    a = Face.define(:cache_a, foreground: "cyan", background: "magenta")
    b = Face.define(:cache_b, foreground: "cyan", background: "magenta")
    assert_equal(a.color_pair, b.color_pair)
  ensure
    Face.delete(:cache_a)
    Face.delete(:cache_b)
  end

  def test_color_pair_cache_different_for_different_colors
    a = Face.define(:diff_a, foreground: "cyan", background: "magenta")
    b = Face.define(:diff_b, foreground: "yellow", background: "magenta")
    assert_not_equal(a.color_pair, b.color_pair)
  ensure
    Face.delete(:diff_a)
    Face.delete(:diff_b)
  end

  def test_color_pair_cache_no_new_slot_for_duplicate
    Face.define(:dup_a, foreground: "white", background: "black")
    slot_before = Face.class_variable_get(:@@next_color_pair)
    Face.define(:dup_b, foreground: "white", background: "black")
    assert_equal(slot_before, Face.class_variable_get(:@@next_color_pair))
  ensure
    Face.delete(:dup_a)
    Face.delete(:dup_b)
  end

  def test_inherit_styles
    Face.define(:bold_face, bold: true, underline: true)
    child = Face.define(:child_bold, inherit: :bold_face)
    assert_equal(Curses::A_BOLD, child.attributes & Curses::A_BOLD)
    assert_equal(Curses::A_UNDERLINE, child.attributes & Curses::A_UNDERLINE)
  ensure
    Face.delete(:bold_face)
    Face.delete(:child_bold)
  end

  def test_override_inherited_attributes
    Face.define(:base_face, foreground: "red", bold: true)
    child = Face.define(:override_face, foreground: "green", bold: false, inherit: :base_face)
    # Foreground should be overridden
    assert_equal("green", child.instance_variable_get(:@foreground))
    # Bold should be explicitly set to false
    assert_equal(0, child.attributes & Curses::A_BOLD)
    # Background should be inherited as default (-1) since parent has no explicit background
    assert_equal(-1, child.instance_variable_get(:@background))
  ensure
    Face.delete(:base_face)
    Face.delete(:override_face)
  end

  def test_inherit_missing_parent
    # Should not raise when parent face doesn't exist
    child = Face.define(:orphan_face, foreground: "yellow", inherit: :nonexistent)
    assert_equal("yellow", child.instance_variable_get(:@foreground))
    assert_equal(-1, child.instance_variable_get(:@background))
  ensure
    Face.delete(:orphan_face)
  end

  def test_inherit_late_parent
    # Child defined before parent (e.g., plugin loads before theme)
    child = Face.define(:early_child, inherit: :late_parent)
    assert_equal(-1, child.instance_variable_get(:@foreground))
    assert_equal(0, child.attributes & Curses::A_BOLD)

    # Parent defined later (e.g., theme activates)
    Face.define(:late_parent, foreground: "red", bold: true)

    # Child should now have inherited attributes
    assert_equal("red", child.instance_variable_get(:@foreground))
    assert_equal(Curses::A_BOLD, child.attributes & Curses::A_BOLD)
  ensure
    Face.delete(:early_child)
    Face.delete(:late_parent)
  end

  def test_inherit_chain_late_resolution
    # grandchild -> child -> parent, all defined in reverse order
    grandchild = Face.define(:gc_face, inherit: :c_face)
    Face.define(:c_face, inherit: :p_face)
    Face.define(:p_face, foreground: "blue", underline: true)

    # Grandchild should pick up attributes through the chain
    assert_equal("blue", grandchild.instance_variable_get(:@foreground))
    assert_equal(Curses::A_UNDERLINE, grandchild.attributes & Curses::A_UNDERLINE)
  ensure
    Face.delete(:gc_face)
    Face.delete(:c_face)
    Face.delete(:p_face)
  end

  def test_inherit_non_symbol_raises
    assert_raise(EditorError) do
      Face.define(:bad_inherit, inherit: "keyword")
    end
  ensure
    Face.delete(:bad_inherit)
  end

  def test_cyclic_inheritance_raises
    Face.define(:cycle_a, foreground: "red")
    Face.define(:cycle_b, inherit: :cycle_a)
    assert_raise(EditorError) do
      Face.define(:cycle_a, inherit: :cycle_b)
    end
    # Self-referential cycle
    assert_raise(EditorError) do
      Face.define(:cycle_a, inherit: :cycle_a)
    end
  ensure
    Face.delete(:cycle_a)
    Face.delete(:cycle_b)
  end

  def test_cyclic_inheritance_raises_for_chain
    Face.define(:chain_a, foreground: "red")
    Face.define(:chain_b, inherit: :chain_a)
    Face.define(:chain_c, inherit: :chain_b)
    assert_raise(EditorError) do
      Face.define(:chain_a, inherit: :chain_c)
    end
  ensure
    Face.delete(:chain_a)
    Face.delete(:chain_b)
    Face.delete(:chain_c)
  end

  def test_inherit_persists_when_updating_without_inherit_key
    Face.define(:persist_parent, foreground: "red")
    child = Face.define(:persist_child, inherit: :persist_parent)
    assert_equal("red", child.instance_variable_get(:@foreground))

    # Re-define child without specifying inherit: — should keep its parent
    Face.define(:persist_child, bold: true)
    assert_equal(:persist_parent, child.instance_variable_get(:@inherit))
    assert_equal("red", child.instance_variable_get(:@foreground))
    assert_equal(Curses::A_BOLD, child.attributes & Curses::A_BOLD)
  ensure
    Face.delete(:persist_parent)
    Face.delete(:persist_child)
  end

  def test_parent_update_propagates_to_children
    Face.define(:prop_parent, foreground: "red")
    child = Face.define(:prop_child, inherit: :prop_parent)
    assert_equal("red", child.instance_variable_get(:@foreground))

    # Update the parent
    Face.define(:prop_parent, foreground: "green")
    assert_equal("green", child.instance_variable_get(:@foreground))
  ensure
    Face.delete(:prop_parent)
    Face.delete(:prop_child)
  end
end
