# Molokai theme for Textbringer
# Based on https://github.com/tomasr/molokai
# Original Monokai theme by Wimer Hazenberg; darker variant by Hamish Stuart Macpherson
#
# GUI hex values from the source's guifg/guibg definitions.
# Dark only (default darker variant, s:molokai_original = 0).

Textbringer::Theme.define "molokai" do |t|
  t.palette :dark do |p|
    # Background / foreground
    p.color :bg,      hex: "#1b1d1e", ansi: "black"        # Normal guibg
    p.color :bg1,     hex: "#403d3d", ansi: "brightblack"   # Visual guibg
    p.color :bg2,     hex: "#1b1d1e", ansi: "black"         # floating window bg (same as bg)
    p.color :fg,      hex: "#f8f8f2", ansi: "white"         # Normal guifg
    p.color :comment, hex: "#7e8e91", ansi: "brightblack"   # Comment guifg
    p.color :gray,    hex: "#455354", ansi: "brightblack"    # StatusLine guifg
    p.color :silver,  hex: "#f8f8f2", ansi: "white"         # StatusLine guibg = fg
    p.color :mid_gray, hex: "#808080", ansi: "brightblack"  # PmenuSel guibg
    p.color :delim,   hex: "#8f8f8f", ansi: "white"         # Delimiter guifg

    # Accent colors
    p.color :pink,    hex: "#f92672", ansi: "red"           # Keyword guifg
    p.color :green,   hex: "#a6e22e", ansi: "green"         # Function guifg
    p.color :yellow,  hex: "#e6db74", ansi: "yellow"        # String guifg
    p.color :purple,  hex: "#ae81ff", ansi: "magenta"       # Number guifg
    p.color :orange,  hex: "#fd971f", ansi: "yellow"        # Identifier guifg
    p.color :cyan,    hex: "#66d9ef", ansi: "cyan"          # Type guifg
    p.color :search,  hex: "#ffe792", ansi: "yellow"        # Search guibg
  end

  t.default_colors foreground: :fg, background: :bg

  # Programming faces
  t.face :comment,                  foreground: :comment
  t.face :preprocessing_directive,  foreground: :green
  t.face :keyword,                  foreground: :pink,     bold: true
  t.face :string,                   foreground: :yellow
  t.face :number,                   foreground: :purple
  t.face :constant,                 foreground: :purple,   bold: true
  t.face :function_name,            foreground: :green
  t.face :type,                     foreground: :cyan
  t.face :variable,                 foreground: :orange
  t.face :operator,                 foreground: :pink
  t.face :punctuation,              foreground: :delim
  t.face :builtin,                  foreground: :cyan
  t.face :property,                 foreground: :orange

  # Basic faces
  t.face :mode_line,                foreground: :gray,     background: :silver
  t.face :link,                     foreground: :cyan,     underline: true
  t.face :control
  t.face :region,                   background: :bg1
  t.face :isearch,                  foreground: :bg,       background: :search
  t.face :floating_window,          foreground: :fg,       background: :bg2

  # Completion faces
  t.face :completion_popup,          foreground: :cyan,    background: :bg
  t.face :completion_popup_selected, foreground: :fg,      background: :mid_gray

  # Dired faces
  t.face :dired_directory,           foreground: :green,   bold: true
  t.face :dired_symlink,             foreground: :cyan
  t.face :dired_executable,          foreground: :green
  t.face :dired_flagged,             foreground: :pink
end
