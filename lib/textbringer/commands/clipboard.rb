# frozen_string_literal: true

require "clipboard"

module Textbringer
  module Commands
    CLIPBOARD_AVAILABLE =
      Clipboard.implementation.name != :Linux ||
      (ENV["DISPLAY"] && system("which xclip > /dev/null 2>&1"))

    if CLIPBOARD_AVAILABLE
      GLOBAL_MAP.define_key("\ew", :clipboard_copy_region)
      GLOBAL_MAP.define_key("\C-w", :clipboard_kill_region)
      GLOBAL_MAP.define_key(?\C-k, :clipboard_kill_line)
      GLOBAL_MAP.define_key("\ed", :clipboard_kill_word)
      GLOBAL_MAP.define_key("\C-y", :clipboard_yank)
    end

    define_command(:clipboard_copy_region) do
      copy_region
      Clipboard.copy(KILL_RING.current)
    end

    define_command(:clipboard_kill_region) do
      kill_region
      Clipboard.copy(KILL_RING.current)
    end

    define_command(:clipboard_kill_line) do
      kill_line
      Clipboard.copy(KILL_RING.current)
    end

    define_command(:clipboard_kill_word) do
      kill_word
      Clipboard.copy(KILL_RING.current)
    end

    define_command(:clipboard_yank) do
      s = Clipboard.paste.encode(Encoding::UTF_8)
      if !s.empty? && (KILL_RING.empty? || KILL_RING.current != s)
        KILL_RING.push(s)
      end
      yank
      Controller.current.this_command = :yank
    end
  end
end
