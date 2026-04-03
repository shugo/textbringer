# GitHub theme for Textbringer
# Based on https://github.com/cormacrelf/vim-colors-github
# Inspired by GitHub's syntax highlighting as of 2018.
#
# GUI hex values from the source's guifg/guibg definitions.

Textbringer::Theme.define "github" do |t|
  t.palette :light do |p|
    # Backgrounds / foreground
    p.color :bg,       hex: "#ffffff", ansi: "white"        # Normal guibg
    p.color :bg1,      hex: "#f6f8fa", ansi: "white"        # overlay/gutter (grey2)
    p.color :vis,      hex: "#e4effb", ansi: "blue"         # Visual guibg (blue2)
    p.color :search,   hex: "#ffffc5", ansi: "yellow"       # Search guibg
    p.color :fg,       hex: "#24292e", ansi: "black"        # Normal guifg (base0)
    p.color :comment,  hex: "#6a737d", ansi: "brightblack"  # Comment guifg (base2)
    p.color :line_nr,  hex: "#babbbc", ansi: "white"        # LineNr guifg (base4)

    # Syntax colors
    p.color :red,      hex: "#d73a49", ansi: "red"          # Statement guifg
    p.color :darkred,  hex: "#b31d28", ansi: "red"          # darkred
    p.color :purple,   hex: "#6f42c1", ansi: "magenta"      # Function guifg
    p.color :green,    hex: "#22863a", ansi: "green"        # html/xml tags
    p.color :orange,   hex: "#e36209", ansi: "yellow"       # orange
    p.color :blue,     hex: "#005cc5", ansi: "blue"         # Identifier guifg
    p.color :darkblue, hex: "#032f62", ansi: "blue"         # String guifg
  end

  t.palette :dark do |p|
    # Backgrounds / foreground (GUI hex from dark mode definitions)
    p.color :bg,       hex: "#24292e", ansi: "black"        # base0 (Normal bg)
    p.color :bg1,      hex: "#353a3f", ansi: "brightblack"  # dcolors.overlay (panels/popups)
    p.color :vis,      hex: "#354a60", ansi: "blue"         # dcolors.blue2 / blues[4]
    p.color :search,   hex: "#595322", ansi: "yellow"       # dcolors.yellow (Search bg)
    p.color :fg,       hex: "#fafbfc", ansi: "white"        # fafbfc (Normal fg)
    p.color :comment,  hex: "#abaeb1", ansi: "brightblack"  # darktext[2] (Comment)
    p.color :line_nr,  hex: "#76787b", ansi: "brightblack"  # numDarkest (base4 in dark)

    # Syntax colors (GUI hex)
    p.color :red,      hex: "#f16636", ansi: "red"          # dcolors.red
    p.color :darkred,  hex: "#b31d28", ansi: "red"          # s:colors.darkred (same both modes)
    p.color :purple,   hex: "#a887e6", ansi: "magenta"      # dcolors.purple
    p.color :green,    hex: "#59b36f", ansi: "green"        # dcolors.green
    p.color :orange,   hex: "#ffa657", ansi: "yellow"       # s:colors.orange (same both modes)
    p.color :blue,     hex: "#4dacfd", ansi: "blue"         # dcolors.blue
    p.color :darkblue, hex: "#c1daec", ansi: "blue"         # dcolors.darkblue = blue1
  end

  t.default_colors foreground: :fg, background: :bg

  # Programming faces
  t.face :comment,                  foreground: :comment   # Comment = base2
  t.face :preprocessing_directive,  foreground: :red       # PreProc = red
  t.face :keyword,                  foreground: :red       # Statement = red
  t.face :string,                   foreground: :darkblue  # String = darkblue
  t.face :number,                   foreground: :blue      # Number → Constant = blue
  t.face :constant,                 foreground: :blue      # Constant = blue
  t.face :function_name,            foreground: :purple    # Function = purple
  t.face :type,                     foreground: :orange    # Type = orange (current GitHub style; vim source used red)
  t.face :variable,                 foreground: :blue      # Identifier = blue
  t.face :operator                                         # no explicit color in source
  t.face :punctuation                                      # Delimiter = fg (ghNormalNoBg)
  t.face :builtin,                  foreground: :purple    # Special = purple
  t.face :property,                 foreground: :blue      # Identifier = blue

  # Basic faces
  # StatusLine: fg=grey2 (~bg1), bg=base0 (~fg) — inverted from Normal in both modes
  t.face :mode_line,                foreground: :bg1,      background: :fg
  t.face :link,                     foreground: :blue,     underline: true
  t.face :control
  t.face :region,                   background: :vis       # Visual = visualblue
  # Search has no explicit fg in source; fg inherits from Normal
  t.face :isearch,                  foreground: :fg,       background: :search
  t.face :floating_window,          foreground: :fg,       background: :bg1

  # Completion faces
  # Pmenu: fg=base3 (≈ comment), bg=overlay (≈ bg1)
  # PmenuSel: fg=overlay (≈ bg1), bg=blue; bold
  t.face :completion_popup,          foreground: :comment, background: :bg1
  t.face :completion_popup_selected, foreground: :bg1,     background: :blue, bold: true

  # Dired faces
  t.face :dired_directory,           foreground: :blue     # Directory → ghBlue
  t.face :dired_symlink,             foreground: :darkblue
  t.face :dired_executable,          foreground: :green
  t.face :dired_flagged,             foreground: :red
end
