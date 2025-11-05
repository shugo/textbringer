# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Textbringer is an Emacs-like text editor written in Ruby. It is extensible by Ruby instead of Lisp and runs in the terminal using ncurses.

**Ruby Version**: Requires Ruby >= 3.2

## Development Commands

### Setup
```bash
bundle install
```

For ncursesw support (required for multibyte characters):
```bash
sudo apt-get install libncursesw5-dev
gem install curses
```

### Running the Editor
```bash
# Run the main executable
./exe/txtb

# Or after installation
txtb
```

### Testing
```bash
# Run all tests
bundle exec rake test

# Or simply (default task)
bundle exec rake

# On Ubuntu/Linux (for CI)
xvfb-run bundle exec rake test

# Run a single test file
ruby -Ilib:test test/textbringer/test_buffer.rb
```

### Build and Release
```bash
# Install gem locally
bundle exec rake install

# Bump version and create release
bundle exec rake bump
```

## Architecture

### Core Components

**Buffer** (`lib/textbringer/buffer.rb`)
- The fundamental text container, similar to Emacs buffers
- Uses a gap buffer implementation (GAP_SIZE = 256) for efficient text editing
- Supports undo/redo with UNDO_LIMIT = 1000
- Handles encoding detection (UTF-8, EUC-JP, Windows-31J) and file format conversion
- Manages marks, point (cursor position), and the kill ring
- Class methods maintain global buffer list (@@list, @@current, @@minibuffer)

**Window** (`lib/textbringer/window.rb`)
- Display abstraction using curses for terminal UI
- Multiple windows can display different buffers or the same buffer
- Window.current tracks the active window
- Echo area (@@echo_area) for messages and minibuffer input
- Manages cursor position and window splitting/deletion

**Controller** (`lib/textbringer/controller.rb`)
- The main event loop and command dispatcher
- Reads key sequences and dispatches to commands
- Handles prefix arguments, keyboard macros, and recursive editing
- Maintains command execution state (this_command, last_command)
- Pre/post command hooks for extensibility

**Mode** (`lib/textbringer/mode.rb`)
- Buffer modes define context-specific behavior and syntax highlighting
- Modes inherit from Mode class (FundamentalMode, ProgrammingMode, RubyMode, CMode, etc.)
- Each mode has its own keymap and syntax table
- `define_local_command` creates mode-specific commands
- Modes are automatically selected based on file_name_pattern or interpreter_name_pattern

**Keymap** (`lib/textbringer/keymap.rb`)
- Tree structure for key bindings (supports multi-stroke sequences)
- Uses `kbd()` function to parse Emacs-style key notation
- Key sequences can bind to commands (symbols) or nested keymaps

**Commands** (`lib/textbringer/commands.rb` and `lib/textbringer/commands/*.rb`)
- Commands are defined using `define_command(name, doc:)`
- Available as module functions in the Commands module
- Command groups: buffers, windows, files, isearch, replace, rectangle, etc.
- All commands accessible via Alt+x or key bindings

### Plugin System

Plugins are loaded from `~/.textbringer/plugins/` via `Plugin.load_plugins`. Examples:
- Mournmail (mail client)
- MedicineShield (Mastodon client)
- textbringer-presentation
- textbringer-ghost_text

### Configuration

User configuration is loaded from:
1. `~/.textbringer/init.rb` (loaded first)
2. `~/.textbringer.rb` (loaded after plugins)

Global configuration hash: `CONFIG` in `lib/textbringer/config.rb`

Key settings:
- `east_asian_ambiguous_width`: Character width (1 or 2)
- `tab_width`, `indent_tabs_mode`: Indentation
- `syntax_highlight`, `highlight_buffer_size_limit`: Syntax highlighting
- `default_input_method`: Input method for non-ASCII text

### Input Methods

Support for non-ASCII input:
- T-Code (`lib/textbringer/input_methods/t_code_input_method.rb`)
- Hiragana (`lib/textbringer/input_methods/hiragana_input_method.rb`)
- Hangul (`lib/textbringer/input_methods/hangul_input_method.rb`)

### Testing Infrastructure

Tests use `Test::Unit` with custom `Textbringer::TestCase` base class in `test/test_helper.rb`.

Key test helpers:
- `FakeController`: Test controller with `test_key_buffer` for simulating input
- `FakeCursesWindow`: Mock curses window for headless testing
- `push_keys(keys)`: Simulate keyboard input
- `mkcdtmpdir`: Create temporary directory for file tests
- `Window.setup_for_test`: Initialize test environment

Tests are organized mirroring lib structure: `test/textbringer/**/*`.

## Code Patterns

### Defining Commands
```ruby
define_command(:command_name, doc: "Description") do
  # Command implementation
  # Access current buffer: Buffer.current
  # Get prefix arg: current_prefix_arg
end
```

### Mode-Specific Commands
```ruby
class MyMode < Mode
  define_local_command(:my_command) do
    # Mode-specific implementation
  end
end
```

### Key Bindings
```ruby
GLOBAL_MAP.define_key("\C-x\C-f", :find_file)
MODE_MAP.define_key("C-c C-c", :compile)
```

### Buffer Operations
- Always use `Buffer.current` to get the active buffer
- `@buffer.point` is the cursor position
- `@buffer.mark` for region operations
- `@buffer.insert(text)`, `@buffer.delete_char(n)` for modifications
- `@buffer.save_point` and `@buffer.goto_char(pos)` for navigation

### Window Management
- `Window.current` is the active window
- `Window.redisplay` updates the display
- `Window.echo_area` for messages
- `message(text)` to display in echo area

## File Organization

- `lib/textbringer.rb`: Main entry point, requires all components
- `lib/textbringer/commands/*.rb`: Command implementations by category
- `lib/textbringer/modes/*.rb`: Major and minor modes
- `lib/textbringer/faces/*.rb`: Syntax highlighting face definitions
- `exe/txtb`: Main executable
- `exe/tbclient`: Client for server mode
- `exe/tbtags`: Tag file generator

## Notes

- The editor is designed to mimic Emacs conventions and terminology
- Key sequences use Emacs notation: C- (Control), M- (Meta/Alt), S- (Shift)
- The codebase uses extensive metaprogramming for command registration and mode definition
- All user-facing text editing operations should go through Buffer methods to maintain undo/redo support
