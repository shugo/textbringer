module Clipboard
  @implementation = nil
end

require "clipboard"

module Textbringer
  module Commands
    CLIPBOARD_AVAILABLE =
      Clipboard.implementation.name != "Clipboard::Linux" ||
      (ENV["DISPLAY"] && system("which xclip > /dev/null 2>&1"))

    if CLIPBOARD_AVAILABLE
      GLOBAL_MAP.define_key("\ew", :clipboard_copy_region)
      GLOBAL_MAP.define_key("\C-w", :clipboard_kill_region)
      GLOBAL_MAP.define_key(?\C-k, :clipboard_kill_line)
      GLOBAL_MAP.define_key("\ed", :clipboard_kill_word)
      GLOBAL_MAP.define_key("\C-y", :clipboard_yank)
      GLOBAL_MAP.define_key("\ey", :clipboard_yank_pop)
    end

    define_command(:clipboard_copy_region, doc: <<~EOD) do
        Copy the region to the kill ring and the clipboard.
      EOD
      copy_region
      Clipboard.copy(KILL_RING.current)
    end

    define_command(:clipboard_kill_region, doc: <<~EOD) do
        Copy the region to the kill ring and the clipboard, and delete
        the region.
      EOD
      kill_region
      Clipboard.copy(KILL_RING.current)
    end

    define_command(:clipboard_kill_line, doc: <<~EOD) do
        Kill the rest of the current line, and copy the killed text to
        the clipboard.
      EOD
      kill_line
      Clipboard.copy(KILL_RING.current)
    end

    define_command(:clipboard_kill_word, doc: <<~EOD) do
        Kill a word, and copy the word to the clipboard.
      EOD
      kill_word
      Clipboard.copy(KILL_RING.current)
    end

    define_command(:clipboard_yank, doc: <<~EOD) do
        If the clipboard contents are different from the last killed text,
        push the contents to the kill ring, and insert it.
        Otherwise, just insert the last text copied in the kill ring.
      EOD
      s = Clipboard.paste.encode(Encoding::UTF_8).gsub(/\r\n/, "\n")
      if !s.empty? && (KILL_RING.empty? || KILL_RING.current != s)
        KILL_RING.push(s)
      end
      yank
      Controller.current.this_command = :yank
    end

    define_command(:clipboard_yank_pop, doc: <<~EOD) do
        Rotate the kill ring, and replace the yanked text, and copy
        the text to the clipboard.
      EOD
      yank_pop
      Clipboard.copy(KILL_RING.current)
    end
  end
end
