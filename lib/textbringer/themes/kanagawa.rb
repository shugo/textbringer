# Kanagawa theme for Textbringer
# Based on https://github.com/rebelot/kanagawa.nvim
# Wave (dark) and Lotus (light) variants.
#
# GUI hex values from the source palette and theme definitions.

Textbringer::Theme.define "kanagawa" do |t|
  t.palette :dark do |p|
    # Background / foreground (wave variant)
    p.color :bg,          hex: "#1f1f28", ansi: "black"        # sumiInk3 – Normal bg
    p.color :bg_dark,     hex: "#181820", ansi: "black"        # sumiInk1 – StatusLine bg
    p.color :bg_popup,    hex: "#223249", ansi: "brightblack"  # waveBlue1 – Pmenu bg
    p.color :bg_vis,      hex: "#223249", ansi: "brightblack"  # waveBlue1 – Visual bg
    p.color :bg_sel,      hex: "#2d4f67", ansi: "brightblack"  # waveBlue2 – PmenuSel bg, Search bg
    p.color :bg_float,    hex: "#16161d", ansi: "black"        # sumiInk0 – float bg
    p.color :fg,          hex: "#dcd7ba", ansi: "white"        # fujiWhite – Normal fg
    p.color :fg_dim,      hex: "#c8c093", ansi: "white"        # oldWhite – StatusLine fg, float fg

    # Syntax colors
    p.color :comment,     hex: "#727169", ansi: "brightblack"  # fujiGray – Comment
    p.color :string,      hex: "#98bb6c", ansi: "green"        # springGreen – String
    p.color :pink,        hex: "#d27e99", ansi: "magenta"      # sakuraPink – Number
    p.color :orange,      hex: "#ffa066", ansi: "yellow"       # surimiOrange – Constant
    p.color :yellow,      hex: "#e6c384", ansi: "yellow"       # carpYellow – Identifier
    p.color :blue,        hex: "#7e9cd8", ansi: "blue"         # crystalBlue – Function
    p.color :violet,      hex: "#957fb8", ansi: "magenta"      # oniViolet – Keyword/Statement
    p.color :gold,        hex: "#c0a36e", ansi: "yellow"       # boatYellow2 – Operator
    p.color :red,         hex: "#e46876", ansi: "red"          # waveRed – PreProc
    p.color :aqua,        hex: "#7aa89f", ansi: "cyan"         # waveAqua2 – Type
    p.color :light_blue,  hex: "#9cabca", ansi: "cyan"         # springViolet2 – Punctuation
    p.color :spring_blue, hex: "#7fb4ca", ansi: "cyan"         # springBlue – Special/Builtin
  end

  t.palette :light do |p|
    # Background / foreground (lotus variant)
    p.color :bg,          hex: "#f2ecbc", ansi: "white"        # lotusWhite3 – Normal bg
    p.color :bg_dark,     hex: "#dcd7ba", ansi: "white"        # lotusGray – StatusLine bg
    p.color :bg_popup,    hex: "#c7d7e0", ansi: "white"        # lotusBlue1 – Pmenu bg
    p.color :bg_sel,      hex: "#9fb5c9", ansi: "white"        # lotusBlue3 – PmenuSel bg, Search bg
    p.color :bg_float,    hex: "#d5cea3", ansi: "white"        # lotusWhite0 – float bg
    p.color :bg_vis,      hex: "#c9cbd1", ansi: "white"        # lotusViolet3 – Visual bg
    p.color :fg,          hex: "#545464", ansi: "black"        # lotusInk1 – Normal fg
    p.color :fg_dim,      hex: "#43436c", ansi: "black"        # lotusInk2 – StatusLine fg

    # Syntax colors
    p.color :comment,     hex: "#8a8980", ansi: "brightblack"  # lotusGray3 – Comment
    p.color :string,      hex: "#6f894e", ansi: "green"        # lotusGreen – String
    p.color :pink,        hex: "#b35b79", ansi: "magenta"      # lotusPink – Number
    p.color :orange,      hex: "#cc6d00", ansi: "yellow"       # lotusOrange – Constant
    p.color :yellow,      hex: "#77713f", ansi: "yellow"       # lotusYellow – Identifier
    p.color :blue,        hex: "#4d699b", ansi: "blue"         # lotusBlue4 – Function
    p.color :violet,      hex: "#624c83", ansi: "magenta"      # lotusViolet4 – Keyword/Statement
    p.color :gold,        hex: "#836f4a", ansi: "yellow"       # lotusYellow2 – Operator
    p.color :red,         hex: "#c84053", ansi: "red"          # lotusRed – PreProc
    p.color :aqua,        hex: "#597b75", ansi: "cyan"         # lotusAqua – Type
    p.color :light_blue,  hex: "#4e8ca2", ansi: "cyan"         # lotusTeal1 – Punctuation
    p.color :spring_blue, hex: "#6693bf", ansi: "cyan"         # lotusTeal2 – Special/Builtin
  end

  t.default_colors foreground: :fg, background: :bg

  # Programming faces
  t.face :comment,                  foreground: :comment
  t.face :string,                   foreground: :string       # syn.string
  t.face :number,                   foreground: :pink         # syn.number
  t.face :constant,                 foreground: :orange       # syn.constant
  t.face :keyword,                  foreground: :violet, bold: true  # syn.keyword + statementStyle
  t.face :preprocessing_directive,  foreground: :red          # syn.preproc
  t.face :function_name,            foreground: :blue         # syn.fun
  t.face :type,                     foreground: :aqua         # syn.type
  t.face :variable,                 foreground: :yellow       # syn.identifier
  t.face :operator,                 foreground: :gold         # syn.operator
  t.face :punctuation,              foreground: :light_blue   # syn.punct
  t.face :builtin,                  foreground: :spring_blue  # syn.special1
  t.face :property,                 foreground: :yellow       # syn.identifier (carpYellow)

  # Basic faces
  t.face :mode_line,                foreground: :fg_dim, background: :bg_dark
  t.face :link,                     foreground: :blue, underline: true
  t.face :control
  t.face :region,                   background: :bg_vis       # Visual = waveBlue1 / lotusViolet3
  t.face :isearch,                  foreground: :fg, background: :bg_sel  # bg_search
  t.face :floating_window,          foreground: :fg_dim, background: :bg_float

  # Completion faces
  t.face :completion_popup,          foreground: :fg,     background: :bg_popup
  t.face :completion_popup_selected, foreground: :fg,     background: :bg_sel

  # Dired faces
  t.face :dired_directory,           foreground: :blue,   bold: true  # Directory
  t.face :dired_symlink,             foreground: :spring_blue         # special1
  t.face :dired_executable,          foreground: :string              # springGreen / lotusGreen
  t.face :dired_flagged,             foreground: :red
end
