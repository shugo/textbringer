require_relative "../test_helper"

class TestTheme < Textbringer::TestCase
  def test_define_and_load
    Theme.define "test_theme" do |t|
      t.palette :dark do |p|
        p.color :fg, hex: "#ffffff", ansi: "white"
        p.color :bg, hex: "#000000", ansi: "black"
      end
      t.face :test_face, foreground: :fg, background: :bg, bold: true
    end
    theme = Theme["test_theme"]
    assert_equal("test_theme", theme.name)
  ensure
    Face.delete(:test_face)
  end

  def test_activate_resolves_palette_colors
    Theme.define "test_resolve" do |t|
      t.palette :dark do |p|
        p.color :my_fg, hex: "#ff0000", ansi: "red"
      end
      t.face :test_resolve_face, foreground: :my_fg, bold: true
    end
    Theme["test_resolve"].activate
    face = Face[:test_resolve_face]
    assert_not_nil(face)
    assert_equal(Curses::A_BOLD, face.attributes & Curses::A_BOLD)
  ensure
    Face.delete(:test_resolve_face)
  end

  def test_activate_raises_on_unknown_palette_color
    Theme.define "test_unknown" do |t|
      t.palette :dark do |p|
        p.color :my_fg, hex: "#ff0000", ansi: "red"
      end
      t.face :test_unknown_face, foreground: :nonexistent
    end
    assert_raise(EditorError) do
      Theme["test_unknown"].activate
    end
  ensure
    Face.delete(:test_unknown_face)
  end

  def test_color_tier_hex_for_256_colors
    old_colors = Curses.colors
    Curses.colors = 256
    assert_equal(:hex, Theme.color_tier)
  ensure
    Curses.colors = old_colors
  end

  def test_color_tier_ansi_for_16_colors
    old_colors = Curses.colors
    Curses.colors = 16
    assert_equal(:ansi, Theme.color_tier)
  ensure
    Curses.colors = old_colors
  end

  def test_color_tier_ansi_for_88_colors
    old_colors = Curses.colors
    Curses.colors = 88
    assert_equal(:ansi, Theme.color_tier)
  ensure
    Curses.colors = old_colors
  end

  def test_background_mode_defaults_to_dark
    old_mode = CONFIG[:background_mode]
    CONFIG[:background_mode] = nil
    Theme.class_variable_set(:@@background_mode, nil)
    assert_equal(:dark, Theme.background_mode)
  ensure
    CONFIG[:background_mode] = old_mode
  end

  def test_background_mode_respects_config
    old_mode = CONFIG[:background_mode]
    CONFIG[:background_mode] = :light
    assert_equal(:light, Theme.background_mode)
  ensure
    CONFIG[:background_mode] = old_mode
  end

  def test_activate_with_inherit
    Theme.define "test_inherit" do |t|
      t.palette :dark do |p|
        p.color :mauve, hex: "#cba6f7", ansi: "magenta"
      end
      t.face :base_kw, foreground: :mauve, bold: true
      t.face :derived_kw, inherit: :base_kw
    end
    Theme["test_inherit"].activate
    base = Face[:base_kw]
    derived = Face[:derived_kw]
    assert_not_nil(derived)
    assert_equal(Curses::A_BOLD, derived.attributes & Curses::A_BOLD)
    # Derived should inherit foreground from base
    assert_equal(base.instance_variable_get(:@foreground),
                 derived.instance_variable_get(:@foreground))
  ensure
    Face.delete(:base_kw)
    Face.delete(:derived_kw)
  end

  def test_activate_sets_default_colors
    Theme.define "test_defcol" do |t|
      t.palette :dark do |p|
        p.color :fg, hex: "#ffffff", ansi: "white"
        p.color :bg, hex: "#000000", ansi: "black"
      end
      t.default_colors foreground: :fg, background: :bg
      t.face :test_defcol_face, foreground: :fg
    end
    Theme["test_defcol"].activate
    fg_num = Color["#ffffff"]
    bg_num = Color["#000000"]
    assert_equal([fg_num, bg_num], Curses.default_colors)
  ensure
    Face.delete(:test_defcol_face)
  end

  def test_activate_resets_default_colors_when_not_specified
    Theme.define "test_with_defcol" do |t|
      t.palette :dark do |p|
        p.color :fg, hex: "#ffffff", ansi: "white"
        p.color :bg, hex: "#000000", ansi: "black"
      end
      t.default_colors foreground: :fg, background: :bg
      t.face :test_wdc_face, foreground: :fg
    end
    Theme["test_with_defcol"].activate
    assert_not_equal([-1, -1], Curses.default_colors)

    Theme.define "test_no_defcol" do |t|
      t.palette :dark do |p|
        p.color :fg, hex: "#ffffff", ansi: "white"
      end
      t.face :test_ndc_face, foreground: :fg
    end
    Theme["test_no_defcol"].activate
    assert_equal([-1, -1], Curses.default_colors)
  ensure
    Face.delete(:test_wdc_face)
    Face.delete(:test_ndc_face)
  end

  def test_activate_default_colors_raises_on_unknown_palette
    Theme.define "test_bad_defcol" do |t|
      t.palette :dark do |p|
        p.color :fg, hex: "#ffffff", ansi: "white"
      end
      t.default_colors foreground: :nonexistent, background: :fg
    end
    assert_raise(EditorError) do
      Theme["test_bad_defcol"].activate
    end
  end

  def test_load_default_activates_faces
    face = Face[:comment]
    assert_not_nil(face)
    face = Face[:keyword]
    assert_not_nil(face)
  end
end
