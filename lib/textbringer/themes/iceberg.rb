# Iceberg theme for Textbringer
# Based on https://github.com/cocopon/iceberg.vim
# A well-designed dark blue color scheme.
#
# GUI hex values from the source's guifg/guibg definitions.

Textbringer::Theme.define "iceberg" do |t|
  t.palette :dark do |p|
    # Background / foreground
    p.color :bg,       hex: "#161821", ansi: "black"        # Normal guibg
    p.color :bg1,      hex: "#1e2132", ansi: "black"        # terminal color0
    p.color :bg_vis,   hex: "#272c42", ansi: "brightblack"  # Visual guibg
    p.color :bg_popup, hex: "#3d425b", ansi: "brightblack"  # Pmenu guibg
    p.color :bg_sel,   hex: "#5b6389", ansi: "brightblack"  # PmenuSel guibg
    p.color :fg,       hex: "#c6c8d1", ansi: "white"        # Normal guifg
    p.color :fg_sel,   hex: "#eff0f4", ansi: "white"        # PmenuSel guifg
    p.color :comment,  hex: "#6b7089", ansi: "brightblack"  # Comment guifg
    p.color :status_bg, hex: "#818596", ansi: "white"       # StatusLine (reverse)
    p.color :status_fg, hex: "#17171b", ansi: "black"       # StatusLine (reverse)

    # Accent colors
    p.color :blue,     hex: "#84a0c6", ansi: "blue"         # Statement/Keyword guifg
    p.color :cyan,     hex: "#89b8c2", ansi: "cyan"         # String/Identifier guifg
    p.color :green,    hex: "#b4be82", ansi: "green"        # PreProc/Special guifg
    p.color :purple,   hex: "#a093c7", ansi: "magenta"      # Constant guifg
    p.color :orange,   hex: "#e4aa80", ansi: "yellow"       # Search guibg
    p.color :search_fg, hex: "#392313", ansi: "black"       # Search guifg
    p.color :red,      hex: "#e27878", ansi: "red"          # terminal color1
  end

  t.palette :light do |p|
    # Background / foreground
    p.color :bg,       hex: "#e8e9ec", ansi: "white"        # Normal guibg
    p.color :bg1,      hex: "#dcdfe7", ansi: "white"        # terminal color0
    p.color :bg_vis,   hex: "#c9cdd7", ansi: "white"        # Visual guibg
    p.color :bg_popup, hex: "#cad0de", ansi: "white"        # Pmenu guibg
    p.color :bg_sel,   hex: "#a7b2cd", ansi: "white"        # PmenuSel guibg
    p.color :fg,       hex: "#33374c", ansi: "black"        # Normal guifg
    p.color :fg_sel,   hex: "#33374c", ansi: "black"        # PmenuSel guifg
    p.color :comment,  hex: "#8389a3", ansi: "brightblack"  # Comment guifg
    p.color :status_bg, hex: "#757ca3", ansi: "brightblack" # StatusLine (reverse)
    p.color :status_fg, hex: "#e8e9ec", ansi: "white"       # StatusLine (reverse)

    # Accent colors
    p.color :blue,     hex: "#2d539e", ansi: "blue"         # Statement/Keyword guifg
    p.color :cyan,     hex: "#3f83a6", ansi: "cyan"         # String/Identifier guifg
    p.color :green,    hex: "#668e3d", ansi: "green"        # PreProc/Special guifg
    p.color :purple,   hex: "#7759b4", ansi: "magenta"      # Constant guifg
    p.color :orange,   hex: "#eac6ad", ansi: "yellow"       # Search guibg
    p.color :search_fg, hex: "#85512c", ansi: "yellow"      # Search guifg
    p.color :red,      hex: "#cc517a", ansi: "red"          # terminal color1
  end

  t.default_colors foreground: :fg, background: :bg

  # Programming faces
  t.face :comment,                  foreground: :comment
  t.face :preprocessing_directive,  foreground: :green     # PreProc
  t.face :keyword,                  foreground: :blue      # Statement
  t.face :string,                   foreground: :cyan      # String
  t.face :number,                   foreground: :purple    # Constant
  t.face :constant,                 foreground: :purple    # Constant
  t.face :function_name,            foreground: :blue      # Function
  t.face :type,                     foreground: :blue      # Type
  t.face :variable,                 foreground: :cyan      # Identifier
  t.face :operator,                 foreground: :blue      # Operator
  t.face :punctuation                                      # Delimiter = fg
  t.face :builtin,                  foreground: :green     # Special
  t.face :property,                 foreground: :cyan      # Identifier

  # Basic faces
  t.face :mode_line,                foreground: :status_fg, background: :status_bg
  t.face :link,                     foreground: :cyan,     underline: true
  t.face :control
  t.face :region,                   background: :bg_vis
  t.face :isearch,                  foreground: :search_fg, background: :orange
  t.face :floating_window,          foreground: :fg,       background: :bg_popup

  # Completion faces
  t.face :completion_popup,          foreground: :fg,      background: :bg_popup
  t.face :completion_popup_selected, foreground: :fg_sel,  background: :bg_sel

  # Dired faces
  t.face :dired_directory,           foreground: :cyan     # Directory
  t.face :dired_symlink,             foreground: :green    # Tag → Special
  t.face :dired_executable,          foreground: :green
  t.face :dired_flagged,             foreground: :red
end
