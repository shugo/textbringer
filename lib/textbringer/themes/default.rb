Textbringer::Theme.define "default" do |t|
  t.palette :dark do |p|
    # Programming
    p.color :comment_color,    hex: "#87875f", term: "red"
    p.color :preproc_color,    hex: "#5faf5f", term: "green"
    p.color :keyword_color,    hex: "#af5fff", term: "magenta"
    p.color :string_color,     hex: "#87d787", term: "green"
    p.color :number_color,     hex: "#00d7d7", term: "cyan"
    p.color :constant_color,   hex: "#5fd7ff", term: "cyan"
    p.color :funcname_color,   hex: "#5fafff", term: "cyan"
    p.color :type_color,       hex: "#5fd7af", term: "green"
    p.color :variable_color,   hex: "#d7af5f", term: "yellow"
    p.color :builtin_color,    hex: "#d75fff", term: "magenta"
    p.color :property_color,   hex: "#87d7d7", term: "cyan"

    # UI
    p.color :link_color,       hex: "#5fafff", term: "cyan"
    p.color :region_bg,        hex: "#005f87", term: "blue"
    p.color :region_fg,        hex: nil,       term: "white"
    p.color :float_bg,         hex: "#1c1c1c", term: "blue"
    p.color :float_fg,         hex: "#d7d7d7", term: "white"
    p.color :popup_bg,         hex: "#303030", term: "black"
    p.color :popup_fg,         hex: "#d0d0d0", term: "white"
    p.color :popup_sel_bg,     hex: "#005faf", term: "blue"
    p.color :popup_sel_fg,     hex: "white",   term: "white"
    p.color :dired_dir_color,  hex: "#5fafff", term: "cyan"
    p.color :dired_sym_color,  hex: "#d75fff", term: "magenta"
    p.color :dired_exe_color,  hex: "#5faf5f", term: "green"
    p.color :dired_flag_color, hex: "#d70000", term: "red"
  end

  t.palette :light do |p|
    # Programming
    p.color :comment_color,    hex: "#af0000", term: "red"
    p.color :preproc_color,    hex: "#005f00", term: "green"
    p.color :keyword_color,    hex: "#8700af", term: "magenta"
    p.color :string_color,     hex: "#005f00", term: "green"
    p.color :number_color,     hex: "#005f87", term: "blue"
    p.color :constant_color,   hex: "#0000af", term: "blue"
    p.color :funcname_color,   hex: "#0000d7", term: "blue"
    p.color :type_color,       hex: "#005f5f", term: "green"
    p.color :variable_color,   hex: "#875f00", term: "magenta"
    p.color :builtin_color,    hex: "#870087", term: "magenta"
    p.color :property_color,   hex: "#005f5f", term: "cyan"

    # UI
    p.color :link_color,       hex: "#0000d7", term: "blue"
    p.color :region_bg,        hex: "#afd7ff", term: "blue"
    p.color :region_fg,        hex: nil,       term: "white"
    p.color :float_bg,         hex: "#e4e4e4", term: "white"
    p.color :float_fg,         hex: "#1c1c1c", term: "black"
    p.color :popup_bg,         hex: "#e4e4e4", term: "white"
    p.color :popup_fg,         hex: "#1c1c1c", term: "black"
    p.color :popup_sel_bg,     hex: "#005faf", term: "blue"
    p.color :popup_sel_fg,     hex: "white",   term: "white"
    p.color :dired_dir_color,  hex: "#8700af", term: "magenta"
    p.color :dired_sym_color,  hex: "#005f5f", term: "cyan"
    p.color :dired_exe_color,  hex: "#005f00", term: "green"
    p.color :dired_flag_color, hex: "#d70000", term: "red"
  end

  # Programming faces
  t.face :comment,                foreground: :comment_color
  t.face :preprocessing_directive, foreground: :preproc_color
  t.face :keyword,                foreground: :keyword_color, bold: true
  t.face :string,                 foreground: :string_color
  t.face :number,                 foreground: :number_color
  t.face :constant,               foreground: :constant_color
  t.face :function_name,          foreground: :funcname_color, bold: true
  t.face :type,                   foreground: :type_color
  t.face :variable,               foreground: :variable_color
  t.face :operator
  t.face :punctuation
  t.face :builtin,                foreground: :builtin_color
  t.face :property,               foreground: :property_color

  # Basic faces
  t.face :mode_line,              reverse: true
  t.face :link,                   foreground: :link_color, bold: true
  t.face :control
  t.face :region,                 foreground: :region_fg, background: :region_bg
  t.face :isearch,                foreground: "black", background: "yellow"
  t.face :floating_window,        foreground: :float_fg, background: :float_bg

  # Completion faces
  t.face :completion_popup,          foreground: :popup_fg, background: :popup_bg
  t.face :completion_popup_selected, foreground: :popup_sel_fg, background: :popup_sel_bg

  # Dired faces
  t.face :dired_directory,   foreground: :dired_dir_color
  t.face :dired_symlink,     foreground: :dired_sym_color
  t.face :dired_executable,  foreground: :dired_exe_color
  t.face :dired_flagged,     foreground: :dired_flag_color
end
