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

  def test_load_default_activates_faces
    face = Face[:comment]
    assert_not_nil(face)
    face = Face[:keyword]
    assert_not_nil(face)
  end
end
