# Catppuccin theme for Textbringer
# Based on https://github.com/catppuccin/nvim
#
# Dark variant: Mocha    Light variant: Latte

Textbringer::Theme.define "default" do |t|
  t.palette :dark do |p|
    # Catppuccin Mocha base tones
    p.color :text,     hex: "#d7d7ff", term: "white"
    p.color :subtext1, hex: "#afafd7", term: "white"
    p.color :subtext0, hex: "#afafd7", term: "white"
    p.color :overlay2, hex: "#8787af", term: "white"
    p.color :overlay1, hex: "#8787af", term: "white"
    p.color :overlay0, hex: "#767676", term: "brightblack"
    p.color :surface2, hex: "#626262", term: "brightblack"
    p.color :surface1, hex: "#4e4e4e", term: "brightblack"
    p.color :surface0, hex: "#3a3a3a", term: "brightblack"
    p.color :base,     hex: "#262626", term: "black"
    p.color :mantle,   hex: "#1c1c1c", term: "black"
    p.color :crust,    hex: "#121212", term: "black"

    # Catppuccin Mocha accent colors
    p.color :red,       hex: "#ff87af", term: "red"
    p.color :maroon,    hex: "#d7afaf", term: "red"
    p.color :peach,     hex: "#ffaf87", term: "yellow"
    p.color :yellow,    hex: "#ffd7af", term: "yellow"
    p.color :green,     hex: "#afd7af", term: "green"
    p.color :teal,      hex: "#87d7d7", term: "cyan"
    p.color :sky,       hex: "#87d7d7", term: "cyan"
    p.color :sapphire,  hex: "#87d7ff", term: "cyan"
    p.color :blue,      hex: "#87afff", term: "blue"
    p.color :lavender,  hex: "#afafff", term: "blue"
    p.color :mauve,     hex: "#d7afff", term: "magenta"
    p.color :pink,      hex: "#ffafd7", term: "magenta"
    p.color :flamingo,  hex: "#ffd7d7", term: "red"
    p.color :rosewater, hex: "#ffd7d7", term: "red"
  end

  t.palette :light do |p|
    # Catppuccin Latte base tones
    p.color :text,     hex: "#585858", term: "black"
    p.color :subtext1, hex: "#5f5f87", term: "black"
    p.color :subtext0, hex: "#767676", term: "brightblack"
    p.color :overlay2, hex: "#878787", term: "brightblack"
    p.color :overlay1, hex: "#949494", term: "white"
    p.color :overlay0, hex: "#a8a8a8", term: "white"
    p.color :surface2, hex: "#b2b2b2", term: "white"
    p.color :surface1, hex: "#c6c6c6", term: "white"
    p.color :surface0, hex: "#d0d0d0", term: "white"
    p.color :base,     hex: "#eeeeee", term: "white"
    p.color :mantle,   hex: "#eeeeee", term: "white"
    p.color :crust,    hex: "#e4e4e4", term: "white"

    # Catppuccin Latte accent colors
    p.color :red,       hex: "#d7005f", term: "red"
    p.color :maroon,    hex: "#d75f5f", term: "red"
    p.color :peach,     hex: "#ff5f00", term: "red"
    p.color :yellow,    hex: "#d78700", term: "yellow"
    p.color :green,     hex: "#5faf00", term: "green"
    p.color :teal,      hex: "#008787", term: "cyan"
    p.color :sky,       hex: "#00afd7", term: "cyan"
    p.color :sapphire,  hex: "#00afaf", term: "cyan"
    p.color :blue,      hex: "#005fff", term: "blue"
    p.color :lavender,  hex: "#5f87ff", term: "blue"
    p.color :mauve,     hex: "#875fff", term: "magenta"
    p.color :pink,      hex: "#d787d7", term: "magenta"
    p.color :flamingo,  hex: "#d78787", term: "red"
    p.color :rosewater, hex: "#d78787", term: "red"
  end

  # Programming faces (from catppuccin/nvim syntax.lua)
  t.face :comment,                foreground: :overlay2
  t.face :preprocessing_directive, foreground: :pink
  t.face :keyword,                foreground: :mauve, bold: true
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
  t.face :completion_popup_selected, background: :surface0, bold: true

  # Dired faces
  t.face :dired_directory,   foreground: :blue
  t.face :dired_symlink,     foreground: :teal
  t.face :dired_executable,  foreground: :green
  t.face :dired_flagged,     foreground: :red
end
