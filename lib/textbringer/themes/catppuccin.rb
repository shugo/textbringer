# Catppuccin theme for Textbringer
# Based on https://github.com/catppuccin/nvim
#
# Dark variant: Mocha    Light variant: Latte
# GUI hex values from the official palette definitions.

Textbringer::Theme.define "catppuccin" do |t|
  t.palette :dark do |p|
    # Catppuccin Mocha base tones
    p.color :text,     hex: "#cdd6f4", ansi: "white"
    p.color :subtext1, hex: "#bac2de", ansi: "white"
    p.color :subtext0, hex: "#a6adc8", ansi: "white"
    p.color :overlay2, hex: "#9399b2", ansi: "white"
    p.color :overlay1, hex: "#7f849c", ansi: "brightblack"
    p.color :overlay0, hex: "#6c7086", ansi: "brightblack"
    p.color :surface2, hex: "#585b70", ansi: "brightblack"
    p.color :surface1, hex: "#45475a", ansi: "brightblack"
    p.color :surface0, hex: "#313244", ansi: "brightblack"
    p.color :base,     hex: "#1e1e2e", ansi: "black"
    p.color :mantle,   hex: "#181825", ansi: "black"
    p.color :crust,    hex: "#11111b", ansi: "black"

    # Catppuccin Mocha accent colors
    p.color :red,       hex: "#f38ba8", ansi: "red"
    p.color :maroon,    hex: "#eba0ac", ansi: "red"
    p.color :peach,     hex: "#fab387", ansi: "yellow"
    p.color :yellow,    hex: "#f9e2af", ansi: "yellow"
    p.color :green,     hex: "#a6e3a1", ansi: "green"
    p.color :teal,      hex: "#94e2d5", ansi: "cyan"
    p.color :sky,       hex: "#89dceb", ansi: "cyan"
    p.color :sapphire,  hex: "#74c7ec", ansi: "cyan"
    p.color :blue,      hex: "#89b4fa", ansi: "blue"
    p.color :lavender,  hex: "#b4befe", ansi: "blue"
    p.color :mauve,     hex: "#cba6f7", ansi: "magenta"
    p.color :pink,      hex: "#f5c2e7", ansi: "magenta"
    p.color :flamingo,  hex: "#f2cdcd", ansi: "red"
    p.color :rosewater, hex: "#f5e0dc", ansi: "red"
  end

  t.palette :light do |p|
    # Catppuccin Latte base tones
    p.color :text,     hex: "#4c4f69", ansi: "black"
    p.color :subtext1, hex: "#5c5f77", ansi: "black"
    p.color :subtext0, hex: "#6c6f85", ansi: "brightblack"
    p.color :overlay2, hex: "#7c7f93", ansi: "brightblack"
    p.color :overlay1, hex: "#8c8fa1", ansi: "white"
    p.color :overlay0, hex: "#9ca0b0", ansi: "white"
    p.color :surface2, hex: "#acb0be", ansi: "white"
    p.color :surface1, hex: "#bcc0cc", ansi: "white"
    p.color :surface0, hex: "#ccd0da", ansi: "white"
    p.color :base,     hex: "#eff1f5", ansi: "white"
    p.color :mantle,   hex: "#e6e9ef", ansi: "white"
    p.color :crust,    hex: "#dce0e8", ansi: "white"

    # Catppuccin Latte accent colors
    p.color :red,       hex: "#d20f39", ansi: "red"
    p.color :maroon,    hex: "#e64553", ansi: "red"
    p.color :peach,     hex: "#fe640b", ansi: "red"
    p.color :yellow,    hex: "#df8e1d", ansi: "yellow"
    p.color :green,     hex: "#40a02b", ansi: "green"
    p.color :teal,      hex: "#179299", ansi: "cyan"
    p.color :sky,       hex: "#04a5e5", ansi: "cyan"
    p.color :sapphire,  hex: "#209fb5", ansi: "cyan"
    p.color :blue,      hex: "#1e66f5", ansi: "blue"
    p.color :lavender,  hex: "#7287fd", ansi: "blue"
    p.color :mauve,     hex: "#8839ef", ansi: "magenta"
    p.color :pink,      hex: "#ea76cb", ansi: "magenta"
    p.color :flamingo,  hex: "#dd7878", ansi: "red"
    p.color :rosewater, hex: "#dc8a78", ansi: "red"
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
