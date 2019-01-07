# frozen_string_literal: true

module Textbringer
  module Commands
    ISEARCH_MODE_MAP = Keymap.new
    (?\x20..?\x7e).each do |c|
      ISEARCH_MODE_MAP.define_key(c, :isearch_printing_char)
    end
    ISEARCH_MODE_MAP.define_key(?\t, :isearch_printing_char)
    ISEARCH_MODE_MAP.handle_undefined_key do |key|
      if key.is_a?(String) && /[\0-\x7f]/ !~ key
        :isearch_printing_char
      else
        nil
      end
    end
    ISEARCH_MODE_MAP.define_key(:backspace, :isearch_delete_char)
    ISEARCH_MODE_MAP.define_key(?\C-h, :isearch_delete_char)
    ISEARCH_MODE_MAP.define_key(?\C-s, :isearch_repeat_forward)
    ISEARCH_MODE_MAP.define_key(?\C-r, :isearch_repeat_backward)
    ISEARCH_MODE_MAP.define_key(?\C-w, :isearch_yank_word_or_char)
    ISEARCH_MODE_MAP.define_key(?\C-m, :isearch_exit)
    ISEARCH_MODE_MAP.define_key(?\C-g, :isearch_abort)

    ISEARCH_STATUS = {
      forward: true,
      string: "",
      last_string: "",
      start: 0,
      last_pos: 0,
      recursive_edit: false
    }

    define_command(:isearch_forward,
                   doc: "Incrementally search forward.") do |**options|
      isearch_mode(true, **options)
    end

    define_command(:isearch_backward,
                   doc: "Incrementally search backward.") do |**options|
      isearch_mode(false, **options)
    end

    def isearch_mode(forward, recursive_edit: false)
      ISEARCH_STATUS[:forward] = forward
      ISEARCH_STATUS[:string] = String.new
      ISEARCH_STATUS[:recursive_edit] = recursive_edit
      Controller.current.overriding_map = ISEARCH_MODE_MAP
      run_hooks(:isearch_mode_hook)
      add_hook(:pre_command_hook, :isearch_pre_command_hook)
      ISEARCH_STATUS[:start] = ISEARCH_STATUS[:last_pos] = Buffer.current.point
      if Buffer.current != Buffer.minibuffer
        message(isearch_prompt, log: false)
      end
      if recursive_edit
        recursive_edit()
      end
    end

    def isearch_prompt
      if ISEARCH_STATUS[:forward]
        "I-search: "
      else
        "I-search backward: "
      end
    end

    def isearch_pre_command_hook
      if /\Aisearch_/ !~ Controller.current.this_command
        isearch_done
      end
    end

    def isearch_done
      Buffer.current.delete_visible_mark
      Controller.current.overriding_map = nil
      remove_hook(:pre_command_hook, :isearch_pre_command_hook)
      ISEARCH_STATUS[:last_string] = ISEARCH_STATUS[:string]
      if ISEARCH_STATUS[:recursive_edit]
        exit_recursive_edit
      end
    end

    define_command(:isearch_exit, doc: "Exit incremental search.") do
      isearch_done
    end

    define_command(:isearch_abort, doc: "Abort incremental search.") do
      goto_char(Buffer.current[:isearch_start])
      isearch_done
      raise Quit
    end

    define_command(:isearch_printing_char, doc: <<~EOD) do
        Add the typed character to the search string and search.
      EOD
      c = Controller.current.last_key
      ISEARCH_STATUS[:string].concat(c)
      isearch_search
    end

    define_command(:isearch_delete_char, doc: <<~EOD) do
        Delete the last character from the search string and search.
      EOD
      ISEARCH_STATUS[:string].chop!
      isearch_search
    end

    define_command(:isearch_yank_word_or_char, doc: <<~EOD) do
        Yank next word or character onto the end of the search string.
      EOD
      buffer = Buffer.current
      if buffer.looking_at?(/(\p{Letter}|\p{Number})+|\s+|./)
        ISEARCH_STATUS[:string].concat(buffer.match_string(0))
        isearch_search
      end
    end

    def isearch_search
      forward = ISEARCH_STATUS[:forward]
      options = if /\A[A-Z]/ =~ ISEARCH_STATUS[:string]
                  nil
                else
                  Regexp::IGNORECASE
                end
      re = Regexp.new(Regexp.quote(ISEARCH_STATUS[:string]), options)
      last_pos = ISEARCH_STATUS[:last_pos]
      offset = forward ? last_pos : last_pos - ISEARCH_STATUS[:string].bytesize
      if Buffer.current.byteindex(forward, re, offset)
        if Buffer.current != Buffer.minibuffer
          message(isearch_prompt + ISEARCH_STATUS[:string], log: false)
        end
        Buffer.current.set_visible_mark(forward ? match_beginning(0) :
                                        match_end(0))
        goto_char(forward ? match_end(0) : match_beginning(0))
      else
        if Buffer.current != Buffer.minibuffer
          message("Failing " + isearch_prompt + ISEARCH_STATUS[:string],
                  log: false)
        end
      end
    end

    def isearch_repeat_forward
      isearch_repeat(true)
    end

    def isearch_repeat_backward
      isearch_repeat(false)
    end

    def isearch_repeat(forward)
      ISEARCH_STATUS[:forward] = forward
      ISEARCH_STATUS[:last_pos] = Buffer.current.point
      if ISEARCH_STATUS[:string].empty?
        ISEARCH_STATUS[:string] = ISEARCH_STATUS[:last_string]
      end
      isearch_search
    end
  end
end
