---
name: port-theme
description: Port a Vim or other editor colorscheme to a Textbringer theme file. Use when the user provides a URL or name of a theme to port.
argument-hint: <github-url-or-theme-name>
---

Port the colorscheme at `$ARGUMENTS` to `lib/textbringer/themes/<name>.rb`.

## Steps

### 1. Fetch the source

Fetch the colorscheme source file. For GitHub repos, fetch the raw file directly (e.g. `https://raw.githubusercontent.com/<owner>/<repo>/master/colors/<name>.vim`).

### 2. Choose colors: cterm over GUI

**For Vim themes:** use `ctermfg`/`ctermbg` values (the 256-color terminal values), NOT `guifg`/`guibg` hex values. The theme will run in a terminal and should match what Vim renders there.

Convert xterm-256 color numbers to hex using these formulas:
- **0–15**: standard ANSI (`#000000`, `#800000`, `#008000`, `#808000`, `#000080`, `#800080`, `#008080`, `#c0c0c0`, `#808080`, `#ff0000`, `#00ff00`, `#ffff00`, `#0000ff`, `#ff00ff`, `#00ffff`, `#ffffff`)
- **16–231** (color cube): `index = n - 16`, then `r = index/36`, `g = (index%36)/6`, `b = index%6`; ramp = `[0, 95, 135, 175, 215, 255]`; hex = `#RRGGBB`
- **232–255** (grayscale): `value = 8 + 10*(n - 232)`; hex = `#VVVVVV`

A Ruby snippet to verify:
```ruby
def xterm256_hex(n)
  if n < 16
    %w[#000000 #800000 #008000 #808000 #000080 #800080 #008080 #c0c0c0
       #808080 #ff0000 #00ff00 #ffff00 #0000ff #ff00ff #00ffff #ffffff][n]
  elsif n < 232
    n -= 16; b = n%6; n /= 6; g = n%6; r = n/6
    ramp = [0,95,135,175,215,255]
    "#%02X%02X%02X" % [ramp[r],ramp[g],ramp[b]]
  else
    v = 8 + 10*(n-232); "#%02X%02X%02X" % [v,v,v]
  end
end
```

For themes with **no cterm values** (GUI only), use the guifg/guibg hex values directly.

### 3. Map highlight groups to Textbringer faces

| Source group(s) | Textbringer face |
|---|---|
| `Normal` | defines `:bg` / `:fg` palette entries |
| `Comment` | `:comment` |
| `String`, `Character` | `:string` |
| `Number`, `Boolean`, `Float` | `:number` |
| `Keyword`, `Conditional`, `Repeat`, `Statement` | `:keyword` (preserve `bold:`) |
| `Constant` | `:constant` (preserve `bold:`) |
| `Function` | `:function_name` |
| `Identifier`, `StorageClass` | `:variable` |
| `Type`, `Typedef`, `Structure` | `:type` |
| `PreProc`, `Define`, `Include`, `PreCondit`, `Macro` | `:preprocessing_directive` |
| `Special` | `:builtin` |
| `Operator` | `:operator` |
| `Delimiter` | `:punctuation` |
| `Search` | `:isearch` |
| `Visual` | `:region` (background only) |
| `StatusLine` | `:mode_line` |
| `Pmenu` | `:completion_popup` |
| `PmenuSel` | `:completion_popup_selected` |
| `Directory` | `:dired_directory` (bold if source does) |
| `Tag` or symlink-like | `:dired_symlink` |

Omit faces with no meaningful color definition in the source.

### 4. Choose ANSI fallbacks

Each palette color needs an `ansi:` value for 8-color terminals. Pick the closest named color:

| Hue / role | `ansi:` value |
|---|---|
| Black, very dark gray | `"black"` |
| Dark gray | `"brightblack"` |
| Medium–light gray, near-white | `"white"` |
| Red, hot pink, crimson | `"red"` |
| Green, lime | `"green"` |
| Yellow, tan, orange, gold | `"yellow"` |
| Blue | `"blue"` |
| Magenta, violet, purple | `"magenta"` |
| Cyan, teal | `"cyan"` |

### 5. Write the theme file

Follow this structure exactly:

```ruby
# <ThemeName> theme for Textbringer
# Based on <source URL>
# <one-line description if useful>

Textbringer::Theme.define "<theme-name>" do |t|
  t.palette :dark do |p|
    # Background / foreground
    p.color :bg,  hex: "#......", ansi: "black"
    p.color :fg,  hex: "#......", ansi: "white"
    # ... other neutral tones ...

    # Accent colors
    p.color :red,  hex: "#......", ansi: "red"
    # ...
  end

  # Include a :light palette only if the source theme has a light variant.

  # Programming faces
  t.face :comment,                 foreground: :comment
  t.face :keyword,                 foreground: :pink, bold: true
  # ...

  # Basic faces
  t.face :mode_line,               foreground: :gray, background: :silver
  t.face :region,                  background: :bg1
  t.face :isearch,                 foreground: :bg, background: :search
  t.face :link,                    foreground: :cyan, underline: true
  t.face :floating_window,         foreground: :fg, background: :bg1

  # Completion faces
  t.face :completion_popup,        foreground: :fg, background: :bg1
  t.face :completion_popup_selected, foreground: :bg, background: :fg

  # Dired faces
  t.face :dired_directory,         foreground: :green, bold: true
  t.face :dired_symlink,           foreground: :cyan
  t.face :dired_executable,        foreground: :green
  t.face :dired_flagged,           foreground: :red
end
```

- Theme name in `define` must match the filename (without `.rb`).
- Include cterm source number in a comment after each palette color for traceability.
- Use `bold: true` where the source specifies `cterm=bold` / `gui=bold`.
- `cterm=reverse` means the terminal's reverse-video attribute (not an fg/bg swap). Only use `reverse: true` when the source group has **no** explicit `ctermfg`/`ctermbg`. If explicit colors are present, use those and omit `reverse:`.

### 6. Verify

Run this to confirm the theme loads without error:

```bash
ruby -Ilib -e "require 'textbringer'; Textbringer::Theme.load('<name>'); puts 'OK'"
```

If it prints `OK`, the theme is ready. Save the file to `lib/textbringer/themes/<name>.rb`.
