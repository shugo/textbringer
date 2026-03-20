# Molokai theme for Textbringer
# Based on https://github.com/tomasr/molokai
# Original Monokai theme by Wimer Hazenberg; darker variant by Hamish Stuart Macpherson
#
# Colors derived from molokai's 256-color (cterm) values.
# Dark only.

Textbringer::Theme.define "molokai" do |t|
  t.palette :dark do |p|
    # Background / foreground  (cterm numbers in comments)
    p.color :bg,      hex: "#121212", ansi: "black"        # 233  Normal bg
    p.color :bg1,     hex: "#262626", ansi: "brightblack"  # 235  Visual, region
    p.color :bg2,     hex: "#303030", ansi: "brightblack"  # 236  LineNr bg, floating windows
    p.color :fg,      hex: "#D0D0D0", ansi: "white"        # 252  Normal fg
    p.color :comment, hex: "#5F5F5F", ansi: "brightblack"  #  59  Comment
    p.color :gray,    hex: "#444444", ansi: "brightblack"  # 238  StatusLine fg
    p.color :silver,  hex: "#DADADA", ansi: "white"        # 253  StatusLine bg
    p.color :mid_gray,hex: "#6C6C6C", ansi: "brightblack"  # 242  PmenuSel bg

    # Accent colors
    p.color :pink,    hex: "#D7005F", ansi: "red"          # 161  Keyword, Operator
    p.color :green,   hex: "#87FF00", ansi: "green"        # 118  Function, PreProc
    p.color :yellow,  hex: "#AFAF87", ansi: "yellow"       # 144  String, Character
    p.color :purple,  hex: "#AF5FFF", ansi: "magenta"      # 135  Number, Boolean, Constant
    p.color :orange,  hex: "#FF8700", ansi: "yellow"       # 208  Identifier, StorageClass
    p.color :cyan,    hex: "#5FD7FF", ansi: "cyan"         #  81  Type, Define, Structure
    p.color :search,  hex: "#FFD787", ansi: "yellow"       # 222  Search bg
  end

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
  t.face :punctuation
  t.face :builtin,                  foreground: :cyan
  t.face :property,                 foreground: :orange

  # Basic faces
  # StatusLine: ctermfg=238 (#444444) on ctermbg=253 (#DADADA)
  t.face :mode_line,                foreground: :gray,     background: :silver
  t.face :link,                     foreground: :cyan,     underline: true
  t.face :control
  t.face :region,                   background: :bg1
  # Search: ctermfg=0 ctermbg=222
  t.face :isearch,                  foreground: :bg,       background: :search
  t.face :floating_window,          foreground: :fg,       background: :bg2

  # Completion faces
  # Pmenu: ctermfg=81 ctermbg=16;  PmenuSel: ctermfg=255 ctermbg=242
  t.face :completion_popup,          foreground: :cyan,    background: :bg
  t.face :completion_popup_selected, foreground: :fg,      background: :mid_gray

  # Dired faces
  t.face :dired_directory,           foreground: :green,   bold: true
  t.face :dired_symlink,             foreground: :cyan
  t.face :dired_executable,          foreground: :green
  t.face :dired_flagged,             foreground: :pink
end
