# Sonokai theme for Textbringer (default style)
# Based on https://github.com/sainnhe/sonokai
#
# A dark theme only. Falls back to dark palette on light terminals.

Textbringer::Theme.define "sonokai" do |t|
  t.palette :dark do |p|
    # Base tones
    p.color :black,    hex: "#080808", ansi: "black"
    p.color :bg_dim,   hex: "#080808", ansi: "black"
    p.color :bg0,      hex: "#262626", ansi: "black"
    p.color :bg1,      hex: "#303030", ansi: "brightblack"
    p.color :bg2,      hex: "#303030", ansi: "brightblack"
    p.color :bg3,      hex: "#3a3a3a", ansi: "brightblack"
    p.color :bg4,      hex: "#3a3a3a", ansi: "brightblack"
    p.color :fg,       hex: "#bcbcbc", ansi: "white"
    p.color :grey,     hex: "#949494", ansi: "white"
    p.color :grey_dim, hex: "#585858", ansi: "brightblack"

    # Accent colors
    p.color :red,      hex: "#ff5f5f", ansi: "red"
    p.color :orange,   hex: "#ffaf5f", ansi: "yellow"
    p.color :yellow,   hex: "#d7af5f", ansi: "yellow"
    p.color :green,    hex: "#87af5f", ansi: "green"
    p.color :blue,     hex: "#87afd7", ansi: "cyan"
    p.color :purple,   hex: "#d787d7", ansi: "magenta"
  end

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
  t.face :isearch,                foreground: :bg0, background: :green
  t.face :floating_window,        foreground: :fg, background: :bg_dim

  # Completion faces
  t.face :completion_popup,          foreground: :fg, background: :bg2
  t.face :completion_popup_selected, foreground: :bg0, background: :blue

  # Dired faces
  t.face :dired_directory,   foreground: :green
  t.face :dired_symlink,     foreground: :blue
  t.face :dired_executable,  foreground: :green
  t.face :dired_flagged,     foreground: :red
end
