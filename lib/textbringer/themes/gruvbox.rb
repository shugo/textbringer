# Gruvbox theme for Textbringer
# Based on https://github.com/morhetz/gruvbox
#
# Dark: bright accent colors on warm dark background
# Light: neutral accent colors on warm light background

Textbringer::Theme.define "gruvbox" do |t|
  t.palette :dark do |p|
    # Base tones (dark background, light foreground)
    p.color :bg0,  hex: "#262626", ansi: "black"
    p.color :bg1,  hex: "#3a3a3a", ansi: "brightblack"
    p.color :bg2,  hex: "#4e4e4e", ansi: "brightblack"
    p.color :bg3,  hex: "#626262", ansi: "brightblack"
    p.color :bg4,  hex: "#767676", ansi: "white"
    p.color :fg1,  hex: "#ffd7af", ansi: "white"
    p.color :fg4,  hex: "#949494", ansi: "white"
    p.color :gray, hex: "#8a8a8a", ansi: "white"

    # Bright accent colors
    p.color :red,    hex: "#d75f5f", ansi: "red"
    p.color :green,  hex: "#afaf00", ansi: "green"
    p.color :yellow, hex: "#ffaf00", ansi: "yellow"
    p.color :blue,   hex: "#87afaf", ansi: "blue"
    p.color :purple, hex: "#d787af", ansi: "magenta"
    p.color :aqua,   hex: "#87af87", ansi: "cyan"
    p.color :orange, hex: "#ff8700", ansi: "yellow"
  end

  t.palette :light do |p|
    # Base tones (light background, dark foreground)
    p.color :bg0,  hex: "#ffffaf", ansi: "white"
    p.color :bg1,  hex: "#ffd7af", ansi: "white"
    p.color :bg2,  hex: "#bcbcbc", ansi: "white"
    p.color :bg3,  hex: "#a8a8a8", ansi: "white"
    p.color :bg4,  hex: "#949494", ansi: "brightblack"
    p.color :fg1,  hex: "#3a3a3a", ansi: "black"
    p.color :fg4,  hex: "#767676", ansi: "brightblack"
    p.color :gray, hex: "#8a8a8a", ansi: "brightblack"

    # Neutral accent colors
    p.color :red,    hex: "#af0000", ansi: "red"
    p.color :green,  hex: "#87af00", ansi: "green"
    p.color :yellow, hex: "#d78700", ansi: "yellow"
    p.color :blue,   hex: "#5f8787", ansi: "blue"
    p.color :purple, hex: "#af5f87", ansi: "magenta"
    p.color :aqua,   hex: "#5faf87", ansi: "cyan"
    p.color :orange, hex: "#d75f00", ansi: "red"
  end

  t.default_colors foreground: :fg1, background: :bg0

  # Programming faces
  t.face :comment,                foreground: :gray
  t.face :preprocessing_directive, foreground: :aqua
  t.face :keyword,                foreground: :red
  t.face :string,                 foreground: :green
  t.face :number,                 foreground: :purple
  t.face :constant,               foreground: :purple
  t.face :function_name,          foreground: :green
  t.face :type,                   foreground: :yellow
  t.face :variable,               foreground: :blue
  t.face :operator
  t.face :punctuation
  t.face :builtin,                foreground: :orange
  t.face :property,               foreground: :blue

  # Basic faces
  t.face :mode_line,              foreground: :bg2, background: :fg1, reverse: true
  t.face :link,                   foreground: :blue, underline: true
  t.face :control
  t.face :region,                 background: :bg3
  t.face :isearch,                foreground: :yellow, background: :bg0, reverse: true
  t.face :floating_window,        foreground: :fg1, background: :bg1

  # Completion faces
  t.face :completion_popup,          foreground: :fg1, background: :bg2
  t.face :completion_popup_selected, foreground: :bg2, background: :blue, bold: true

  # Dired faces
  t.face :dired_directory,   foreground: :green, bold: true
  t.face :dired_symlink,     foreground: :aqua
  t.face :dired_executable,  foreground: :green
  t.face :dired_flagged,     foreground: :red
end
