## 0.3.0

* toggle_test_command supports RSpec now.
* Improve auto indentation in the Ruby mode.

## 0.2.9

* Add the following new commands:
    * list_buffers
    * jit_pause
    * jit_resume

## 0.2.8

* Highlight control characters.

## 0.2.7

* Add isearch_yank_word_or_char.

## 0.2.6

* Add the following new commands:
    * fill_paragraph
    * fill_region
    * open_line
* Complete encoding names in set_buffer_file_encoding and
  revert_buffer_with_encoding.

## 0.2.5

* Add next_tick!.
* Add Buffer#replace.

## 0.2.4

* Remove Buffer#on_modified and add Buffer#on instead.

## 0.2.3

* Add the on_modified callback to Buffer.
* Use Gem.find_latest_files to find plugins.
* Turn off synatx highlighting when the buffer is binary.
* Add define_local_command.

## 0.2.2

* Rename read_char to read_event and add read_char as a new method.
* Add next_tick and background for background threads.
* Add the force: option to kill_buffer.
* bind C-? ([delete] on Mac) to backward_delete_char.
  Pull request #23 by moguno.
* Make commands module_functions.
* Use fiddley instead of ffi.

## 0.2.1

* Add revert_buffer and revert_buffer_with_encoding.
* Fixes for an ncurses issue on macOS that unget_wch() doesn't work with
  multibyte characters.

## 0.2.0

* Add bury_buffer and unbury_buffer.

## 0.1.9

* Support registers.
* Support plugins.
* Support global mark ring.
* Support keyboard macro.
* Support help (describe_bindings, describe_command, and describe_key).
* Add tbtags.
* Add the commands back_to_indentation, indent_region, delete_indentation,
  shrink_window, and shrink_window_if_larger_than_buffer.

## 0.1.8

* Support syntax highlighting.
* Add the commands grep, gsub, and enlarge_window.
* Don't translate CR into LF.

## 0.1.7

* Support EditorConfig.
* Add CONFIG[:ambiguos_east_asian_width].
* Add C mode.
* Add the *Completions* buffer.
* Echo multi-character commands in the echo area.

## 0.1.6

* Fix bugs of clipboard commands.

## 0.1.5

* Support clipboard.
* Added tests.
* Bug fixes.

## 0.1.4

* Add dabbrev_expand (M-/).
* Add find_tag (M-.) and pop_tag_mark (M-*).
* Add toggle_test_command (C-c t).
* Force binmode for Windows.

## 0.1.3

* Fix an infinite loop bug on Windows.

## 0.1.2

* Use curses instead of ncursesw.
* Support Windows.
* Dump unsaved buffers to ~/.textbringer/buffer_dump when textbringer crashes.
* Many bug fixes.

## 0.1.1

* Rename exe/tb to exe/textbringer to avoid conflict with akr/tb.

## 0.1.0

* First version
