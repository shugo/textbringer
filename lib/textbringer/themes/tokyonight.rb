# Tokyo Night theme for Textbringer
# Based on https://github.com/folke/tokyonight.nvim
# Night variant (dark only). GUI hex colors — no cterm values in source.
# Computed colors derived from tokyonight's blend formulas.

Textbringer::Theme.define "tokyonight" do |t|
  t.palette :dark do |p|
    # Background / foreground (night variant)
    p.color :bg,      hex: "#1a1b26", ansi: "black"        # bg
    p.color :bg_dark, hex: "#16161e", ansi: "black"        # bg_dark → popups, statusline
    p.color :bg_hl,   hex: "#292e42", ansi: "brightblack"  # bg_highlight → floating windows
    p.color :bg_vis,  hex: "#283457", ansi: "brightblack"  # bg_visual = blend(blue0, 0.4, bg)
    p.color :sel_bg,  hex: "#343a55", ansi: "brightblack"  # PmenuSel bg = blend(fg_gutter, 0.8, bg)
    p.color :search,  hex: "#3d59a1", ansi: "blue"         # bg_search = blue0
    p.color :fg,      hex: "#c0caf5", ansi: "white"        # fg
    p.color :fg_dark, hex: "#a9b1d6", ansi: "white"        # fg_dark → statusline fg
    p.color :comment, hex: "#565f89", ansi: "brightblack"  # comment

    # Accent colors
    p.color :blue,    hex: "#7aa2f7", ansi: "blue"         # Function, Directory, link
    p.color :cyan,    hex: "#7dcfff", ansi: "cyan"         # PreProc, Keyword (base groups)
    p.color :purple,  hex: "#9d7cd8", ansi: "magenta"      # @keyword (treesitter default)
    p.color :magenta, hex: "#bb9af7", ansi: "magenta"      # Identifier, Statement
    p.color :green,   hex: "#9ece6a", ansi: "green"        # String
    p.color :teal,    hex: "#73daca", ansi: "cyan"         # @property, @variable.member
    p.color :orange,  hex: "#ff9e64", ansi: "yellow"       # Constant
    p.color :red,     hex: "#f7768e", ansi: "red"          # @variable.builtin, flagged files
    p.color :blue1,   hex: "#2ac3de", ansi: "cyan"         # Type, Special
    p.color :blue5,   hex: "#89ddff", ansi: "cyan"         # Operator, punctuation delimiters
  end

  t.default_colors foreground: :fg, background: :bg

  # Programming faces
  t.face :comment,                  foreground: :comment
  t.face :preprocessing_directive,  foreground: :cyan     # PreProc = c.cyan
  t.face :keyword,                  foreground: :purple   # @keyword = c.purple (treesitter)
  t.face :string,                   foreground: :green    # String = c.green
  t.face :number,                   foreground: :orange   # Number → Constant = c.orange
  t.face :constant,                 foreground: :orange   # Constant = c.orange
  t.face :function_name,            foreground: :blue     # Function = c.blue
  t.face :type,                     foreground: :blue1    # Type = c.blue1
  t.face :variable,                 foreground: :magenta  # Identifier = c.magenta
  t.face :operator,                 foreground: :blue5    # Operator = c.blue5
  t.face :punctuation,              foreground: :blue5    # @punctuation.delimiter = c.blue5
  t.face :builtin,                  foreground: :blue1    # Special = c.blue1
  t.face :property,                 foreground: :teal     # @property = c.green1 (teal)

  # Basic faces
  # StatusLine: fg = fg_dark, bg = bg_dark
  t.face :mode_line,                foreground: :fg_dark, background: :bg_dark
  t.face :link,                     foreground: :blue,    underline: true
  t.face :control
  t.face :region,                   background: :bg_vis   # Visual = bg_visual
  # Search: bg = bg_search (blue0 = #3d59a1), fg = fg
  t.face :isearch,                  foreground: :fg,      background: :search
  t.face :floating_window,          foreground: :fg,      background: :bg_hl

  # Completion faces
  # Pmenu: bg = bg_dark, fg = fg
  # PmenuSel: bg = blend(fg_gutter, 0.8, bg) ≈ #343a55
  t.face :completion_popup,          foreground: :fg,     background: :bg_dark
  t.face :completion_popup_selected, foreground: :fg,     background: :sel_bg

  # Dired faces
  t.face :dired_directory,           foreground: :blue,   bold: true  # Directory = c.blue
  t.face :dired_symlink,             foreground: :teal
  t.face :dired_executable,          foreground: :green
  t.face :dired_flagged,             foreground: :red
end
