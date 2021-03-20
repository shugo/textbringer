## 1.0.7

* Support endless method definitions in ruby-mode.
* Updated mazegaki.dic.

## 1.0.6

* Add the Hiragana input method.
* Add make_directory.
* Bug fixes.

## 1.0.5

* Support the Japanese input method T-Code.

## 1.0.4

* Support Ruby 3.0.
* Do not record backtrace of Quit (C-g).

## 1.0.3

* Fix indentation bugs.
* Fix a bug of fourground! when it is called in the main thread.

## 1.0.2

* Add isearch_quoted_insert.
* Use M- notation instead of ESC in define_key and help.
* Add indent_new_comment_line_command.
* Add find_alternate_file.
* Fix indentation bugs in the Ruby mode.

## 1.0.1

* Support pattern matching in the Ruby mode.
* Bug fixes.

## 1.0.0

* Add mark_whole_buffer.
* Add zap_to_char.
* Exit on SIGTERM, SIGHUP etc.

## 0.3.2

* Drop Ruby 2.3 support.
* Support C-x u.

## 0.3.1

* Depend on curses 1.2.6 or later for mingw.
* Add tbclient.

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
