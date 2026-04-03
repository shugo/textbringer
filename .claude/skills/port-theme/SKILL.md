---
name: port-theme
description: Port a Vim or other editor colorscheme to a Textbringer theme file. Use when the user provides a URL or name of a theme to port.
argument-hint: <github-url-or-theme-name>
---

Port the colorscheme at `$ARGUMENTS` to `lib/textbringer/themes/<name>.rb`.

## Steps

### 1. Identify the theme type and fetch the source

**Vim themes** (`.vim` files) live in `colors/<name>.vim`. Fetch the raw file:
```
https://raw.githubusercontent.com/<owner>/<repo>/master/colors/<name>.vim
```

**Neovim themes** (Lua-based) are structured differently. Typical layout:
```
lua/<name>/
  colors/        ← palette definitions (storm.lua, night.lua, …)
  groups/        ← highlight group tables (base.lua, syntax.lua, treesitter.lua, …)
  colors/init.lua ← computed/derived colors (blended backgrounds, semantic aliases)
```
Fetch `colors/init.lua` (or the main palette file) first to get raw hex values, then `groups/base.lua` and `groups/treesitter.lua` (or equivalent) to see how highlight groups map to palette entries. Also fetch `colors/init.lua` for derived colors computed from blend formulas.

### 2. Choose colors — always use GUI hex values

**Always use GUI hex values** (`guifg`/`guibg` for Vim, hex strings for Neovim) as the `hex:` value in the palette. Textbringer supports true color via `TERM=xterm-direct` and uses these hex values directly in that mode. For 256-color terminals, the `Color` module automatically finds the closest 256-color palette match.

**Vim themes:**
Use the `guifg`/`guibg` hex values (e.g. `#F92672`), NOT `ctermfg`/`ctermbg` numbers. If a Vim theme only provides cterm values without GUI values, convert them to hex using the xterm-256 color table:
- **0–15**: standard ANSI (`#000000`, `#800000`, `#008000`, `#808000`, `#000080`, `#800080`, `#008080`, `#c0c0c0`, `#808080`, `#ff0000`, `#00ff00`, `#ffff00`, `#0000ff`, `#ff00ff`, `#00ffff`, `#ffffff`)
- **16–231** (color cube): `index = n - 16`, then `r = index/36`, `g = (index%36)/6`, `b = index%6`; ramp = `[0, 95, 135, 175, 215, 255]`; hex = `#RRGGBB`
- **232–255** (grayscale): `value = 8 + 10*(n - 232)`; hex = `#VVVVVV`

**Neovim themes:**
Use the GUI hex strings from the palette as-is.

For colors computed via blend formulas (e.g. `blend(color, alpha, bg)`), compute them manually:
```
result = alpha * color_component + (1 - alpha) * bg_component   (per R, G, B channel)
```

### 3. Map highlight groups to Textbringer faces

When a Neovim theme defines both traditional groups (e.g. `Keyword`) and treesitter groups (e.g. `@keyword`), **prefer the treesitter group** — it is what Neovim actually applies by default.

| Source group(s) | Textbringer face |
|---|---|
| `Normal` | defines `:bg` / `:fg` palette entries |
| `Comment`, `@comment` | `:comment` |
| `String`, `Character`, `@string` | `:string` |
| `Number`, `Boolean`, `Float`, `@number`, `@boolean` | `:number` |
| `Keyword`, `Conditional`, `Repeat`, `Statement`, `@keyword`, `@keyword.conditional` | `:keyword` (preserve `bold:`) |
| `Constant`, `@constant` | `:constant` (preserve `bold:`) |
| `Function`, `@function`, `@function.method` | `:function_name` |
| `Identifier`, `StorageClass`, `@variable` | `:variable` |
| `Type`, `Typedef`, `Structure`, `@type` | `:type` |
| `PreProc`, `Define`, `Include`, `PreCondit`, `Macro`, `@keyword.import`, `@keyword.directive` | `:preprocessing_directive` |
| `Special`, `@constant.builtin`, `@function.builtin` | `:builtin` |
| `Operator`, `@operator` | `:operator` |
| `Delimiter`, `@punctuation.delimiter`, `@punctuation.bracket` | `:punctuation` |
| `@property`, `@variable.member` | `:property` |
| `Search`, `IncSearch` | `:isearch` |
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
#
# GUI hex values from the source's guifg/guibg definitions.

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

  t.default_colors foreground: :fg, background: :bg

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
- **Hex values must be lowercase** (`#d7005f`, not `#D7005F`).
- Always put a space after the comma in `p.color` arguments: `p.color :name, hex: …` (not `p.color :name,hex: …`).
- Include a comment after each palette color noting the source variable name (e.g. `# Normal guifg`, `# c.blue`, `# bright_red`).
- Use `bold: true` where the source specifies `cterm=bold` / `gui=bold` / `bold = true`.
- Neovim themes often apply `italic` to keywords/functions via `opts.styles`; skip italic since Textbringer does not support it.

### 6. Verify

Run this to confirm the theme loads without error:

```bash
ruby -Ilib -e "require 'textbringer'; Textbringer::Theme.load('<name>'); puts 'OK'"
```

If it prints `OK`, the theme is ready. Save the file to `lib/textbringer/themes/<name>.rb`.
