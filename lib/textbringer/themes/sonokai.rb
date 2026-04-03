# Sonokai theme for Textbringer (default style)
# Based on https://github.com/sainnhe/sonokai
#
# GUI hex values from the source's default style palette.
# A dark theme only. Falls back to dark palette on light terminals.

Textbringer::Theme.define "sonokai" do |t|
  t.palette :dark do |p|
    # Base tones
    p.color :black,    hex: "#181819", ansi: "black"
    p.color :bg_dim,   hex: "#222327", ansi: "black"
    p.color :bg0,      hex: "#2c2e34", ansi: "black"
    p.color :bg1,      hex: "#33353f", ansi: "brightblack"
    p.color :bg2,      hex: "#363944", ansi: "brightblack"
    p.color :bg3,      hex: "#3b3e48", ansi: "brightblack"
    p.color :bg4,      hex: "#414550", ansi: "brightblack"
    p.color :fg,       hex: "#e2e2e3", ansi: "white"
    p.color :grey,     hex: "#7f8490", ansi: "white"
    p.color :grey_dim, hex: "#595f6f", ansi: "brightblack"

    # Accent colors
    p.color :red,      hex: "#fc5d7c", ansi: "red"
    p.color :orange,   hex: "#f39660", ansi: "yellow"
    p.color :yellow,   hex: "#e7c664", ansi: "yellow"
    p.color :green,    hex: "#9ed072", ansi: "green"
    p.color :blue,     hex: "#76cce0", ansi: "cyan"
    p.color :purple,   hex: "#b39df3", ansi: "magenta"

    # Filled colors for UI
    p.color :filled_blue, hex: "#85d3f2", ansi: "cyan"
  end

  t.default_colors foreground: :fg, background: :bg0

  # Programming faces (from sonokai highlight groups)
  t.face :comment,                foreground: :grey
  t.face :preprocessing_directive, foreground: :red
  t.face :keyword,                foreground: :red
  t.face :string,                 foreground: :yellow
  t.face :number,                 foreground: :purple
  t.face :constant,               foreground: :orange
  t.face :function_name,          foreground: :green
  t.face :type,                   foreground: :blue
  t.face :variable,               foreground: :orange
  t.face :operator,               foreground: :red
  t.face :punctuation
  t.face :builtin,                foreground: :green
  t.face :property,               foreground: :blue

  # Basic faces
  t.face :mode_line,              foreground: :fg, background: :bg3
  t.face :link,                   foreground: :blue, underline: true
  t.face :control
  t.face :region,                 background: :bg4
  t.face :isearch,                foreground: :bg0, background: :green, reverse: true
  t.face :floating_window,        foreground: :fg, background: :bg_dim

  # Completion faces
  t.face :completion_popup,          foreground: :fg, background: :bg2
  t.face :completion_popup_selected, foreground: :bg0, background: :filled_blue

  # Dired faces
  t.face :dired_directory,   foreground: :green
  t.face :dired_symlink,     foreground: :blue
  t.face :dired_executable,  foreground: :green
  t.face :dired_flagged,     foreground: :red
end
