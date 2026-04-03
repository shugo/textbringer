# Gruvbox theme for Textbringer
# Based on https://github.com/morhetz/gruvbox
#
# GUI hex values from the source's guifg/guibg definitions.
# Dark: bright accent colors on warm dark background
# Light: faded accent colors on warm light background

Textbringer::Theme.define "gruvbox" do |t|
  t.palette :dark do |p|
    # Base tones (dark background, light foreground)
    p.color :bg0,  hex: "#282828", ansi: "black"        # dark0
    p.color :bg1,  hex: "#3c3836", ansi: "brightblack"  # dark1
    p.color :bg2,  hex: "#504945", ansi: "brightblack"  # dark2
    p.color :bg3,  hex: "#665c54", ansi: "brightblack"  # dark3
    p.color :bg4,  hex: "#7c6f64", ansi: "white"        # dark4
    p.color :fg1,  hex: "#ebdbb2", ansi: "white"        # light1 (Normal guifg)
    p.color :fg4,  hex: "#a89984", ansi: "white"        # light4
    p.color :gray, hex: "#928374", ansi: "white"        # gray_245

    # Bright accent colors
    p.color :red,    hex: "#fb4934", ansi: "red"        # bright_red
    p.color :green,  hex: "#b8bb26", ansi: "green"      # bright_green
    p.color :yellow, hex: "#fabd2f", ansi: "yellow"     # bright_yellow
    p.color :blue,   hex: "#83a598", ansi: "blue"       # bright_blue
    p.color :purple, hex: "#d3869b", ansi: "magenta"    # bright_purple
    p.color :aqua,   hex: "#8ec07c", ansi: "cyan"       # bright_aqua
    p.color :orange, hex: "#fe8019", ansi: "yellow"     # bright_orange
  end

  t.palette :light do |p|
    # Base tones (light background, dark foreground)
    p.color :bg0,  hex: "#fbf1c7", ansi: "white"        # light0
    p.color :bg1,  hex: "#ebdbb2", ansi: "white"        # light1
    p.color :bg2,  hex: "#d5c4a1", ansi: "white"        # light2
    p.color :bg3,  hex: "#bdae93", ansi: "white"        # light3
    p.color :bg4,  hex: "#a89984", ansi: "brightblack"  # light4
    p.color :fg1,  hex: "#3c3836", ansi: "black"        # dark1 (Normal guifg)
    p.color :fg4,  hex: "#7c6f64", ansi: "brightblack"  # dark4
    p.color :gray, hex: "#928374", ansi: "brightblack"  # gray_244

    # Faded accent colors
    p.color :red,    hex: "#9d0006", ansi: "red"        # faded_red
    p.color :green,  hex: "#79740e", ansi: "green"      # faded_green
    p.color :yellow, hex: "#b57614", ansi: "yellow"     # faded_yellow
    p.color :blue,   hex: "#076678", ansi: "blue"       # faded_blue
    p.color :purple, hex: "#8f3f71", ansi: "magenta"    # faded_purple
    p.color :aqua,   hex: "#427b58", ansi: "cyan"       # faded_aqua
    p.color :orange, hex: "#af3a03", ansi: "red"        # faded_orange
  end

  t.default_colors foreground: :fg1, background: :bg0

  # Programming faces
  t.face :comment,                foreground: :gray
  t.face :preprocessing_directive, foreground: :aqua
  t.face :keyword,                foreground: :red
  t.face :string,                 foreground: :green
  t.face :number,                 foreground: :purple
  t.face :constant,               foreground: :purple
  t.face :function_name,          foreground: :green,  bold: true
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
