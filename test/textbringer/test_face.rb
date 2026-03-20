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
    assert_equal(parent.color_pair != child.color_pair, true)
    # Child should inherit parent's foreground/background
    assert_equal("red", child.instance_variable_get(:@foreground))
    assert_equal("blue", child.instance_variable_get(:@background))
  ensure
    Face.delete(:parent_face)
    Face.delete(:child_face)
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
