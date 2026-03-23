# Catppuccin theme for Textbringer
# Based on https://github.com/catppuccin/nvim
#
# Dark variant: Mocha    Light variant: Latte

Textbringer::Theme.define "catppuccin" do |t|
  t.palette :dark do |p|
    # Catppuccin Mocha base tones
    p.color :text,     hex: "#d7d7ff", ansi: "white"
    p.color :subtext1, hex: "#afafd7", ansi: "white"
    p.color :subtext0, hex: "#afafd7", ansi: "white"
    p.color :overlay2, hex: "#8787af", ansi: "white"
    p.color :overlay1, hex: "#8787af", ansi: "white"
    p.color :overlay0, hex: "#767676", ansi: "brightblack"
    p.color :surface2, hex: "#626262", ansi: "brightblack"
    p.color :surface1, hex: "#4e4e4e", ansi: "brightblack"
    p.color :surface0, hex: "#3a3a3a", ansi: "brightblack"
    p.color :base,     hex: "#262626", ansi: "black"
    p.color :mantle,   hex: "#1c1c1c", ansi: "black"
    p.color :crust,    hex: "#121212", ansi: "black"

    # Catppuccin Mocha accent colors
    p.color :red,       hex: "#ff87af", ansi: "red"
    p.color :maroon,    hex: "#d7afaf", ansi: "red"
    p.color :peach,     hex: "#ffaf87", ansi: "yellow"
    p.color :yellow,    hex: "#ffd7af", ansi: "yellow"
    p.color :green,     hex: "#afd7af", ansi: "green"
    p.color :teal,      hex: "#87d7d7", ansi: "cyan"
    p.color :sky,       hex: "#87d7d7", ansi: "cyan"
    p.color :sapphire,  hex: "#87d7ff", ansi: "cyan"
    p.color :blue,      hex: "#87afff", ansi: "blue"
    p.color :lavender,  hex: "#afafff", ansi: "blue"
    p.color :mauve,     hex: "#d7afff", ansi: "magenta"
    p.color :pink,      hex: "#ffafd7", ansi: "magenta"
    p.color :flamingo,  hex: "#ffd7d7", ansi: "red"
    p.color :rosewater, hex: "#ffd7d7", ansi: "red"
  end

  t.palette :light do |p|
    # Catppuccin Latte base tones
    p.color :text,     hex: "#585858", ansi: "black"
    p.color :subtext1, hex: "#5f5f87", ansi: "black"
    p.color :subtext0, hex: "#767676", ansi: "brightblack"
    p.color :overlay2, hex: "#878787", ansi: "brightblack"
    p.color :overlay1, hex: "#949494", ansi: "white"
    p.color :overlay0, hex: "#a8a8a8", ansi: "white"
    p.color :surface2, hex: "#b2b2b2", ansi: "white"
    p.color :surface1, hex: "#c6c6c6", ansi: "white"
    p.color :surface0, hex: "#d0d0d0", ansi: "white"
    p.color :base,     hex: "#eeeeee", ansi: "white"
    p.color :mantle,   hex: "#eeeeee", ansi: "white"
    p.color :crust,    hex: "#e4e4e4", ansi: "white"

    # Catppuccin Latte accent colors
    p.color :red,       hex: "#d7005f", ansi: "red"
    p.color :maroon,    hex: "#d75f5f", ansi: "red"
    p.color :peach,     hex: "#ff5f00", ansi: "red"
    p.color :yellow,    hex: "#d78700", ansi: "yellow"
    p.color :green,     hex: "#5faf00", ansi: "green"
    p.color :teal,      hex: "#008787", ansi: "cyan"
    p.color :sky,       hex: "#00afd7", ansi: "cyan"
    p.color :sapphire,  hex: "#00afaf", ansi: "cyan"
    p.color :blue,      hex: "#005fff", ansi: "blue"
    p.color :lavender,  hex: "#5f87ff", ansi: "blue"
    p.color :mauve,     hex: "#875fff", ansi: "magenta"
    p.color :pink,      hex: "#d787d7", ansi: "magenta"
    p.color :flamingo,  hex: "#d78787", ansi: "red"
    p.color :rosewater, hex: "#d78787", ansi: "red"
  end

  t.default_colors foreground: :text, background: :base

  # Programming faces (from catppuccin/nvim syntax.lua)
  t.face :comment,                foreground: :overlay2
  t.face :preprocessing_directive, foreground: :pink
  t.face :keyword,                foreground: :mauve
  t.face :string,                 foreground: :green
  t.face :number,                 foreground: :peach
  t.face :constant,               foreground: :peach
  t.face :function_name,          foreground: :blue
  t.face :type,                   foreground: :yellow
  t.face :variable,               foreground: :flamingo
  t.face :operator,               foreground: :sky
  t.face :punctuation
  t.face :builtin,                foreground: :red
  t.face :property,               foreground: :lavender

  # Basic faces (from catppuccin/nvim editor.lua)
  t.face :mode_line,              foreground: :text, background: :mantle
  t.face :link,                   foreground: :blue, underline: true
  t.face :control
  t.face :region,                 background: :surface1
  t.face :isearch,                foreground: :mantle, background: :red
  t.face :floating_window,        foreground: :text, background: :mantle

  # Completion faces
  t.face :completion_popup,          foreground: :overlay2, background: :mantle
  t.face :completion_popup_selected, background: :surface0

  # Dired faces
  t.face :dired_directory,   foreground: :blue
  t.face :dired_symlink,     foreground: :teal
  t.face :dired_executable,  foreground: :green
  t.face :dired_flagged,     foreground: :red
end
