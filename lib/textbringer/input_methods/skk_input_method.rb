require "open-uri"
require "fileutils"
require "socket"
require "timeout"

module Textbringer
  CONFIG[:skk_dictionary_path] = File.expand_path("~/.textbringer/skk/SKK-JISYO.L")
  CONFIG[:skk_user_dictionary_path] = File.expand_path("~/.textbringer/skk/skk-jisyo.utf8")
  CONFIG[:skk_server_host] = nil   # nil = disabled (default)
  CONFIG[:skk_server_port] = 1178

  class SkkInputMethod < InputMethod
    HIRAGANA_TABLE = {
      "a" => "あ", "i" => "い", "u" => "う", "e" => "え", "o" => "お",
      "ka" => "か", "ki" => "き", "ku" => "く", "ke" => "け", "ko" => "こ",
      "ga" => "が", "gi" => "ぎ", "gu" => "ぐ", "ge" => "げ", "go" => "ご",
      "sa" => "さ", "si" => "し", "su" => "す", "se" => "せ", "so" => "そ",
      "za" => "ざ", "zi" => "じ", "zu" => "ず", "ze" => "ぜ", "zo" => "ぞ",
      "sha" => "しゃ", "shi" => "し", "shu" => "しゅ", "she" => "しぇ", "sho" => "しょ",
      "ja" => "じゃ", "ji" => "じ", "ju" => "じゅ", "je" => "じぇ", "jo" => "じょ",
      "ta" => "た", "ti" => "ち", "tu" => "つ", "te" => "て", "to" => "と",
      "da" => "だ", "di" => "ぢ", "du" => "づ", "de" => "で", "do" => "ど",
      "cha" => "ちゃ", "chi" => "ち", "chu" => "ちゅ", "che" => "ちぇ", "cho" => "ちょ",
      "na" => "な", "ni" => "に", "nu" => "ぬ", "ne" => "ね", "no" => "の",
      "ha" => "は", "hi" => "ひ", "hu" => "ふ", "he" => "へ", "ho" => "ほ",
      "ba" => "ば", "bi" => "び", "bu" => "ぶ", "be" => "べ", "bo" => "ぼ",
      "pa" => "ぱ", "pi" => "ぴ", "pu" => "ぷ", "pe" => "ぺ", "po" => "ぽ",
      "ma" => "ま", "mi" => "み", "mu" => "む", "me" => "め", "mo" => "も",
      "ya" => "や", "yi" => "い", "yu" => "ゆ", "ye" => "いぇ", "yo" => "よ",
      "ra" => "ら", "ri" => "り", "ru" => "る", "re" => "れ", "ro" => "ろ",
      "wa" => "わ", "wi" => "ゐ", "wu" => "う", "we" => "ゑ", "wo" => "を",
      "nn" => "ん",
      "kya" => "きゃ", "kyi" => "きぃ", "kyu" => "きゅ", "kye" => "きぇ", "kyo" => "きょ",
      "gya" => "ぎゃ", "gyi" => "ぎぃ", "gyu" => "ぎゅ", "gye" => "ぎぇ", "gyo" => "ぎょ",
      "sya" => "しゃ", "syi" => "しぃ", "syu" => "しゅ", "sye" => "しぇ", "syo" => "しょ",
      "zya" => "じゃ", "zyi" => "じぃ", "zyu" => "じゅ", "zye" => "じぇ", "zyo" => "じょ",
      "tya" => "ちゃ", "tyi" => "ちぃ", "tyu" => "ちゅ", "tye" => "ちぇ", "tyo" => "ちょ",
      "dya" => "ぢゃ", "dyi" => "ぢぃ", "dyu" => "ぢゅ", "dye" => "ぢぇ", "dyo" => "ぢょ",
      "nya" => "にゃ", "nyi" => "にぃ", "nyu" => "にゅ", "nye" => "にぇ", "nyo" => "にょ",
      "hya" => "ひゃ", "hyi" => "ひぃ", "hyu" => "ひゅ", "hye" => "ひぇ", "hyo" => "ひょ",
      "bya" => "びゃ", "byi" => "びぃ", "byu" => "びゅ", "bye" => "びぇ", "byo" => "びょ",
      "pya" => "ぴゃ", "pyi" => "ぴぃ", "pyu" => "ぴゅ", "pye" => "ぴぇ", "pyo" => "ぴょ",
      "mya" => "みゃ", "myi" => "みぃ", "myu" => "みゅ", "mye" => "みぇ", "myo" => "みょ",
      "rya" => "りゃ", "ryi" => "りぃ", "ryu" => "りゅ", "rye" => "りぇ", "ryo" => "りょ",
      "fa" => "ふぁ", "fi" => "ふぃ", "fu" => "ふ", "fe" => "ふぇ", "fo" => "ふぉ",
      "va" => "ヴぁ", "vi" => "ヴぃ", "vu" => "ヴ", "ve" => "ヴぇ", "vo" => "ヴぉ",
      "tsa" => "つぁ", "tsi" => "つぃ", "tse" => "つぇ", "tso" => "つぉ",
      "la" => "ぁ", "li" => "ぃ", "lu" => "ぅ", "le" => "ぇ", "lo" => "ぉ",
      "lya" => "ゃ", "lyu" => "ゅ", "lyo" => "ょ",
      "lka" => "ヵ", "lke" => "ヶ",
      "xtu" => "っ", "xtsu" => "っ",
      "xya" => "ゃ", "xyu" => "ゅ", "xyo" => "ょ",
      "xa" => "ぁ", "xi" => "ぃ", "xu" => "ぅ", "xe" => "ぇ", "xo" => "ぉ",
      "-" => "ー", "," => "、", "." => "。", "[" => "「", "]" => "」",
      "z-" => "～", "z." => "…", "z/" => "・", "z," => "‥",
      "z(" => "（", "z)" => "）", "z[" => "『", "z]" => "』",
      "zh" => "←", "zj" => "↓", "zk" => "↑", "zl" => "→", "zL" => "⇒",
      "z " => "　",
    }

    HIRAGANA_PREFIXES = HIRAGANA_TABLE.keys.flat_map { |s|
      (s.size - 1).times.map { |i| s[0, i + 1] }
    }.uniq

    KATAKANA_TABLE = HIRAGANA_TABLE.transform_values { |v|
      v.chars.map { |c|
        c.ord.between?(0x3041, 0x3096) ? (c.ord + 0x60).chr("UTF-8") : c
      }.join
    }

    HANKAKU_KATAKANA_TABLE = {
      "a" => "ｱ", "i" => "ｲ", "u" => "ｳ", "e" => "ｴ", "o" => "ｵ",
      "ka" => "ｶ", "ki" => "ｷ", "ku" => "ｸ", "ke" => "ｹ", "ko" => "ｺ",
      "ga" => "ｶﾞ", "gi" => "ｷﾞ", "gu" => "ｸﾞ", "ge" => "ｹﾞ", "go" => "ｺﾞ",
      "sa" => "ｻ", "si" => "ｼ", "su" => "ｽ", "se" => "ｾ", "so" => "ｿ",
      "za" => "ｻﾞ", "zi" => "ｼﾞ", "zu" => "ｽﾞ", "ze" => "ｾﾞ", "zo" => "ｿﾞ",
      "sha" => "ｼｬ", "shi" => "ｼ", "shu" => "ｼｭ", "she" => "ｼｪ", "sho" => "ｼｮ",
      "ja" => "ｼﾞｬ", "ji" => "ｼﾞ", "ju" => "ｼﾞｭ", "je" => "ｼﾞｪ", "jo" => "ｼﾞｮ",
      "ta" => "ﾀ", "ti" => "ﾁ", "tu" => "ﾂ", "te" => "ﾃ", "to" => "ﾄ",
      "da" => "ﾀﾞ", "di" => "ﾁﾞ", "du" => "ﾂﾞ", "de" => "ﾃﾞ", "do" => "ﾄﾞ",
      "cha" => "ﾁｬ", "chi" => "ﾁ", "chu" => "ﾁｭ", "che" => "ﾁｪ", "cho" => "ﾁｮ",
      "na" => "ﾅ", "ni" => "ﾆ", "nu" => "ﾇ", "ne" => "ﾈ", "no" => "ﾉ",
      "ha" => "ﾊ", "hi" => "ﾋ", "hu" => "ﾌ", "he" => "ﾍ", "ho" => "ﾎ",
      "ba" => "ﾊﾞ", "bi" => "ﾋﾞ", "bu" => "ﾌﾞ", "be" => "ﾍﾞ", "bo" => "ﾎﾞ",
      "pa" => "ﾊﾟ", "pi" => "ﾋﾟ", "pu" => "ﾌﾟ", "pe" => "ﾍﾟ", "po" => "ﾎﾟ",
      "ma" => "ﾏ", "mi" => "ﾐ", "mu" => "ﾑ", "me" => "ﾒ", "mo" => "ﾓ",
      "ya" => "ﾔ", "yu" => "ﾕ", "yo" => "ﾖ",
      "ra" => "ﾗ", "ri" => "ﾘ", "ru" => "ﾙ", "re" => "ﾚ", "ro" => "ﾛ",
      "wa" => "ﾜ", "wo" => "ｦ",
      "nn" => "ﾝ",
      "kya" => "ｷｬ", "kyu" => "ｷｭ", "kyo" => "ｷｮ",
      "gya" => "ｷﾞｬ", "gyu" => "ｷﾞｭ", "gyo" => "ｷﾞｮ",
      "sya" => "ｼｬ", "syu" => "ｼｭ", "syo" => "ｼｮ",
      "zya" => "ｼﾞｬ", "zyu" => "ｼﾞｭ", "zyo" => "ｼﾞｮ",
      "tya" => "ﾁｬ", "tyu" => "ﾁｭ", "tyo" => "ﾁｮ",
      "dya" => "ﾁﾞｬ", "dyu" => "ﾁﾞｭ", "dyo" => "ﾁﾞｮ",
      "nya" => "ﾆｬ", "nyu" => "ﾆｭ", "nyo" => "ﾆｮ",
      "hya" => "ﾋｬ", "hyu" => "ﾋｭ", "hyo" => "ﾋｮ",
      "bya" => "ﾋﾞｬ", "byu" => "ﾋﾞｭ", "byo" => "ﾋﾞｮ",
      "pya" => "ﾋﾟｬ", "pyu" => "ﾋﾟｭ", "pyo" => "ﾋﾟｮ",
      "mya" => "ﾐｬ", "myu" => "ﾐｭ", "myo" => "ﾐｮ",
      "rya" => "ﾘｬ", "ryu" => "ﾘｭ", "ryo" => "ﾘｮ",
      "fa" => "ﾌｧ", "fi" => "ﾌｨ", "fu" => "ﾌ", "fe" => "ﾌｪ", "fo" => "ﾌｫ",
      "," => "､", "." => "｡",
    }

    HANKAKU_KATAKANA_PREFIXES = HANKAKU_KATAKANA_TABLE.keys.flat_map { |s|
      (s.size - 1).times.map { |i| s[0, i + 1] }
    }.uniq

    STATUS_NAMES = {
      hiragana: "かな",
      katakana: "カナ",
      hankaku_katakana: "半ｶﾅ",
      zenkaku_ascii: "全英",
      ascii: "SKK:"
    }

    DEFAULT_CURSOR_COLORS = {
      hiragana:         "pink",
      katakana:         "green",
      hankaku_katakana: "blue",
      zenkaku_ascii:    "yellow",
      ascii:            nil,    # nil = reset to terminal default
    }

    # Mirrors ddskk's skk-kakutei-history: the okuri-nasi yomi confirmed in
    # this session, most recent first, shared by all buffers, and used to
    # complete an empty yomi (skk-comp-by-history).
    KAKUTEI_HISTORY_LIMIT = 100 # skk-kakutei-history-limit
    @@kakutei_history = []

    def self.kakutei_history
      @@kakutei_history
    end

    # Mirrors ddskk's skk-get-jisyo-buffer, which reads a dictionary file
    # into a single buffer shared by every buffer using SKK: the user
    # dictionary is loaded once per path and shared by all instances, so
    # that saving from one buffer does not drop what another one learned.
    @@user_dictionaries = {}

    # A user dictionary candidate like (skk-ignore-dic-word "留守電"),
    # which ddskk evaluates to hide the quoted words of the system
    # dictionary (see purge_candidate).
    IGNORE_DIC_WORD_RE = /\A\(skk-ignore-dic-word((?: +"[^"]*")+)\)\z/

    def initialize
      super
      @mode = :hiragana  # :hiragana | :katakana | :hankaku_katakana | :zenkaku_ascii | :ascii
      @phase = :normal   # :normal | :converting | :selecting
      @roman_buffer = +""
      @okuri_roman = nil       # the consonant that started okurigana (dictionary fallback)
      @okuri_start_pos = nil   # buffer position of the "*" marker; nil = no okurigana
      # @yomi/@okuri_kana are snapshots taken when entering the selecting
      # phase (see start_selecting); during converting they are derived
      # from the buffer via current_yomi/current_okuri_kana instead.
      @yomi = +""
      @okuri_kana = nil
      @candidates = []
      @candidate_index = 0
      @base_candidates = []  # the system dictionary's candidates for @lookup_key
      @marker_pos = nil
      @lookup_key = nil
      # Yomi completion state: the yomi it started from, the matching
      # user-dictionary keys, and the index of the one currently shown.
      @comp_prefix = nil
      @comp_candidates = nil
      @comp_index = nil
      @comp_message_shown = false
      # Whether the previous key was TAB/Shift-TAB, standing in for ddskk's
      # (eq last-command 'skk-comp-do).
      @last_key_completed = false
      @okuriiari = nil
      @okurinasi = nil
      @user_okuriiari = nil
      @user_okurinasi = nil
      @skk_server_socket = nil
      @prefix_window = nil
      @prefix_buffer = nil
    end

    def toggle
      super
      if @enabled
        update_cursor_color
      else
        reset_cursor_color
        close_skk_server
        close_prefix_window
      end
    end

    def disable
      super
      reset_cursor_color
      close_skk_server
      close_prefix_window
    end

    def on_activate
      update_cursor_color if @enabled
    end

    def on_deactivate
      reset_cursor_color if @enabled
      close_prefix_window
    end

    def status
      STATUS_NAMES[@mode]
    end

    def handle_event(event)
      # Hidden first, not to be drawn over what the event inserts: cut in
      # two by it, a wide character would not be shown properly.
      @prefix_window.hide if @prefix_window&.visible?
      result =
        case @phase
        when :normal     then handle_normal(event)
        when :converting then handle_converting(event)
        when :selecting  then handle_selecting(event)
        end
      update_prefix_window
      result
    end

    private

    # Mirrors ddskk's skk-insert-prefix, which shows the unconfirmed
    # romaji at point with an overlay when skk-echo is non-nil (the
    # default).  Textbringer has no overlays, so it is shown in a
    # floating window over point instead, which leaves the buffer and
    # its undo history untouched.  During conversion the romaji is
    # already in the buffer (see insert_roman_preview).
    def update_prefix_window
      if @enabled && @phase == :normal && !@roman_buffer.empty? &&
          !isearch_mode?
        show_prefix_window
      else
        close_prefix_window
      end
    end

    def show_prefix_window
      window = Window.current
      width = prefix_window_width(window.buffer)
      y, x = prefix_window_position(window, width)
      @prefix_buffer ||= Buffer.new(name: " *skk-prefix*", undo_limit: 0)
      @prefix_buffer.replace(
        @roman_buffer + " " * (width - Buffer.display_width(@roman_buffer))
      )
      if @prefix_window.nil? || @prefix_window.deleted?
        # Like ddskk's skk-prefix-*-face; defined here, after the colors
        # are set up, unless the user has defined it.
        Face.define(:skk_prefix, underline: true) unless Face[:skk_prefix]
        @prefix_window = FloatingWindow.new(1, width, y, x,
                                            buffer: @prefix_buffer,
                                            face: :skk_prefix)
      else
        @prefix_window.resize(1, width) if @prefix_window.columns != width
        @prefix_window.move_to(y: y, x: x)
      end
      @prefix_window.show
      Window.redisplay
      # Put the cursor after the romaji, as after characters typed; the
      # next redisplay puts it back at point.
      cursor_x = [x - window.x + Buffer.display_width(@roman_buffer),
                  window.columns - 1].min
      window.window.setpos(y - window.y, cursor_x)
      window.window.noutrefresh
      Window.update
    end

    # Wide enough to cover the characters after point as a whole: a wide
    # character cut in two by the window would not be shown properly
    # again when the window is gone.
    def prefix_window_width(buffer)
      width = Buffer.display_width(@roman_buffer)
      covered = 0
      buffer.save_excursion do
        while covered < width && !buffer.end_of_buffer? &&
            buffer.char_after != "\n"
          covered += Buffer.display_width(buffer.char_after)
          buffer.forward_char
        end
      end
      [width, covered].max
    end

    # A window sticking out of the screen is not drawn at all, so romaji
    # that does not fit in the rest of the line goes to the beginning of
    # the next line, where the kana will go.  The echo area has no next
    # line, so it is moved to the left there instead.
    def prefix_window_position(window, width)
      y = window.cursor.y
      x = window.cursor.x
      if x + width > window.columns
        if window.echo_area?
          x = [window.columns - width, 0].max
        else
          y += 1
          x = 0
        end
      end
      [window.y + y, window.x + x]
    end

    def close_prefix_window
      return if @prefix_window.nil?
      @prefix_window.close
      @prefix_window = nil
    end

    def handle_normal(event)
      unless event.is_a?(String)
        @roman_buffer = +""
        return event
      end

      case event
      when "\C-j"
        @roman_buffer = +""
        @mode = :hiragana
        Window.redisplay
        update_cursor_color
        nil
      when "\C-q"
        if [:hiragana, :katakana].include?(@mode)
          @roman_buffer = +""
          @mode = :hankaku_katakana
          Window.redisplay
          update_cursor_color
        elsif @mode == :hankaku_katakana
          @roman_buffer = +""
          @mode = :hiragana
          Window.redisplay
          update_cursor_color
        else
          return process_romaji(event)
        end
        nil
      when "q"
        if @mode == :hiragana
          @roman_buffer = +""
          @mode = :katakana
          Window.redisplay
          update_cursor_color
          nil
        elsif @mode == :katakana || @mode == :hankaku_katakana
          @roman_buffer = +""
          @mode = :hiragana
          Window.redisplay
          update_cursor_color
          nil
        else
          process_romaji(event)
        end
      when "l"
        if @roman_buffer != "z" && [:hiragana, :katakana, :hankaku_katakana].include?(@mode)
          @roman_buffer = +""
          @mode = :ascii
          Window.redisplay
          update_cursor_color
          nil
        else
          process_romaji(event)
        end
      when "L"
        if @roman_buffer != "z" && [:hiragana, :katakana, :hankaku_katakana].include?(@mode)
          @roman_buffer = +""
          @mode = :zenkaku_ascii
          Window.redisplay
          update_cursor_color
          nil
        else
          process_romaji(event)
        end
      when /\A[A-Z]\z/
        if [:hiragana, :katakana, :hankaku_katakana].include?(@mode)
          start_converting(event.downcase)
        else
          process_romaji(event)
        end
      when /\A[\x00-\x09\x0b-\x1f\x7f]\z/
        # Control characters other than C-j and C-q pass through unchanged
        @roman_buffer = +""
        event
      else
        process_romaji(event)
      end
    end

    def handle_converting(event)
      # Like ddskk, any key clears the message a completion left behind.
      if @comp_message_shown
        Window.echo_area.clear_message
        @comp_message_shown = false
      end

      # Like ddskk's skk-comp-do setting this-command, only TAB/Shift-TAB
      # keep the flag up for the next key; any other key drops it.
      after_completion = @last_key_completed
      @last_key_completed = false

      if backspace_event?(event)
        backspace_converting
        return nil
      end

      # Like skk-insert, "." and "," (skk-next-completion-char and
      # skk-previous-completion-char) move through the candidates only
      # right after a completion, and are typed as "。" and "、" otherwise.
      if event == "\t" || (after_completion && event == ".")
        complete_yomi(after_completion)
        @last_key_completed = true
        return nil
      end

      if event == :btab || (after_completion && event == ",")
        complete_yomi_backward(after_completion)
        @last_key_completed = true
        return nil
      end

      unless event.is_a?(String)
        discard_roman_preview
        commit_converting
        return event
      end

      # Control characters not handled below: commit conversion and pass through
      if event.bytesize == 1 && (event.ord < 0x20 || event.ord == 0x7f) &&
          event != "\C-g" && event != "\C-j"
        discard_roman_preview
        commit_converting
        return event
      end

      case event
      when "\C-g"
        discard_roman_preview
        if after_completion && @comp_prefix
          cancel_completion
        else
          cancel_converting
        end
        nil
      when "\C-j"
        discard_roman_preview
        commit_converting
        nil
      when " "
        discard_roman_preview
        start_selecting
        nil
      when "q"
        toggle_yomi_katakana
        nil
      when /\A[A-Z]\z/
        if @okuri_start_pos.nil?
          discard_roman_preview
          start_okurigana(event.downcase)
        else
          process_converting_romaji(event.downcase)
        end
        nil
      else
        process_converting_romaji(event)
      end
    end

    def handle_selecting(event)
      unless event.is_a?(String)
        confirm_selecting
        return event
      end

      case event
      when "\C-g"
        cancel_selecting
        nil
      when " "
        next_candidate
        nil
      when "x"
        prev_candidate
        nil
      when "X"
        purge_candidate
        nil
      when "\r", "\n"
        confirm_selecting
        nil
      else
        confirm_selecting
        handle_event(event)
      end
    end

    def process_romaji(event)
      case @mode
      when :ascii
        return event
      when :zenkaku_ascii
        if event.ord.between?(0x21, 0x7E)
          return (event.ord + 0xFEE0).chr("UTF-8")
        else
          return event
        end
      end

      # Special "n" handling: flush "ん" before appending if next char won't extend "n"
      if @roman_buffer == "n" && !%w[n y a i u e o].include?(event)
        kana = kana_for_mode("ん")
        @roman_buffer = +""
        insert_kana(kana)
      end

      @roman_buffer << event

      table = current_table
      prefixes = current_prefixes

      kana = table[@roman_buffer]
      if kana
        @roman_buffer = +""
        insert_kana(kana_for_mode(kana))
        return nil
      end

      if prefixes.include?(@roman_buffer)
        return nil
      end

      # Double consonant: e.g. "kk" → っ + keep second "k"
      if @roman_buffer.size >= 2
        first = @roman_buffer[0]
        rest = @roman_buffer[1..]
        if first == rest[0] && first =~ /[bcdfghjklmnpqrstvwxyz]/
          geminate = kana_for_mode("っ")
          @roman_buffer = +rest
          insert_kana(geminate)
          # Now check if rest completes a kana
          kana2 = table[@roman_buffer]
          if kana2
            @roman_buffer = +""
            insert_kana(kana_for_mode(kana2))
          end
          return nil
        end
      end

      # No match: if single char, return it to let the controller handle it
      # (consistent with HiraganaInputMethod#flush for unrecognized chars)
      if @roman_buffer.size == 1
        char = @roman_buffer
        @roman_buffer = +""
        return char
      end

      # Multi-char: flush first char as-is, retry with last char
      first_char = @roman_buffer[0]
      last_char = @roman_buffer[-1]
      @roman_buffer = +""
      with_target_buffer { |b| b.insert(first_char) }
      Window.redisplay
      process_romaji(last_char)
    end

    def insert_kana(kana)
      with_target_buffer do |buffer|
        buffer.insert(kana)
      end
      Window.redisplay
      nil
    end

    # Mirrors ddskk: the headword and okurigana being composed are just
    # ordinary buffer text between markers ("▽"/"*"), so a confirmed kana
    # is always simply inserted here -- there is no need to decide whether
    # it belongs to the yomi or the okurigana, unlike a design that tracks
    # them in separate string variables.
    def process_converting_romaji(event)
      # Remove the preview of the previously buffered, unconfirmed romaji
      delete_roman_preview

      # Special "n" handling: flush "ん" before appending if next char won't extend "n"
      if @roman_buffer == "n" && !%w[n y a i u e o].include?(event)
        @roman_buffer = +""
        insert_kana(converting_kana_for_mode("ん"))
      end

      @roman_buffer << event

      # ddskk's romaji rules pair each kana with its katakana form and pick
      # one by the current mode (skk-katakana), so a katakana-mode headword
      # is katakana from the first kana onward, not converted afterward.
      table = converting_table
      prefixes = HIRAGANA_PREFIXES

      kana = table[@roman_buffer]
      if kana
        @roman_buffer = +""
        insert_kana(kana)
        start_selecting if @okuri_start_pos
        return
      end

      if prefixes.include?(@roman_buffer)
        insert_roman_preview(@roman_buffer)
        return
      end

      # Double consonant handling
      if @roman_buffer.size >= 2
        first = @roman_buffer[0]
        rest = @roman_buffer[1..]
        if first == rest[0] && first =~ /[bcdfghjklmnpqrstvwxyz]/
          insert_kana(converting_kana_for_mode("っ"))
          @roman_buffer = +rest  # Keep the second consonant buffered
          insert_roman_preview(@roman_buffer)
          return
        end
      end

      # No match: if single char, insert as-is
      if @roman_buffer.size == 1
        char = @roman_buffer
        @roman_buffer = +""
        insert_kana(char)
        return
      end

      # Multi-char: flush first char as-is, retry with last char
      first_char = @roman_buffer[0]
      last_char = @roman_buffer[-1]
      @roman_buffer = +""
      insert_kana(first_char)
      process_converting_romaji(last_char)
    end

    def start_converting(first_char)
      @phase = :converting
      @okuri_roman = nil
      @okuri_start_pos = nil
      @roman_buffer = +""
      reset_completion
      @last_key_completed = false
      with_target_buffer do |buffer|
        @marker_pos = buffer.point
        buffer.insert("▽")
      end
      Window.redisplay
      update_cursor_color
      process_converting_romaji(first_char)
      nil
    end

    def start_okurigana(c)
      @okuri_roman = c.dup
      with_target_buffer do |buffer|
        @okuri_start_pos = buffer.point
        buffer.insert("*")
      end
      Window.redisplay
      kana = converting_table[c]
      if kana
        # Vowel okurigana: insert the kana immediately.
        # (A vowel is never a prefix of a longer romaji sequence, so it's always complete.)
        @roman_buffer = +""
        insert_kana(kana)
        start_selecting
      else
        @roman_buffer = c.dup
        insert_roman_preview(@roman_buffer)
      end
    end

    def insert_roman_preview(s)
      with_target_buffer do |buffer|
        buffer.insert(s)
      end
      Window.redisplay
    end

    def delete_roman_preview
      return if @roman_buffer.empty?
      with_target_buffer do |buffer|
        buffer.delete_region(buffer.point - @roman_buffer.bytesize, buffer.point)
      end
    end

    def discard_roman_preview
      delete_roman_preview
      @roman_buffer = +""
    end

    def backspace_event?(event)
      event == :backspace ||
        (event.is_a?(String) && (event == "\C-h" || event.ord == 0x7f))
    end

    # Mirrors ddskk, where the headword being composed is ordinary
    # buffer text, so backspace just deletes its last character one
    # step at a time: unconfirmed romaji first, then okurigana, then
    # the confirmed yomi, cancelling the conversion once everything is
    # gone.
    def backspace_converting
      unless @roman_buffer.empty?
        delete_roman_preview
        @roman_buffer = @roman_buffer[0..-2]
        if @roman_buffer.empty?
          # Only undo entering okurigana entirely (removing the "*" marker)
          # if no okurigana kana has been confirmed yet -- e.g. after a
          # geminate consonant already confirmed "っ", erasing the preview
          # of the following consonant must not discard that "っ" along
          # with the okurigana marker.
          if @okuri_start_pos &&
              with_target_buffer(&:point) == @okuri_start_pos + "*".bytesize
            undo_okurigana_start
          end
          Window.redisplay
        else
          insert_roman_preview(@roman_buffer)
        end
        return
      end

      point = with_target_buffer(&:point)
      boundary = @okuri_start_pos ? @okuri_start_pos + "*".bytesize :
        @marker_pos + "▽".bytesize

      if point == boundary
        if @okuri_start_pos
          undo_okurigana_start
          Window.redisplay
        else
          cancel_converting
        end
        return
      end

      with_target_buffer do |buffer|
        last = buffer.char_before(buffer.point)
        buffer.delete_region(buffer.point - last.bytesize, buffer.point)
      end
      Window.redisplay
    end

    # Undoes entering okurigana (removes the "*" marker), as if the
    # uppercase key that started it had never been pressed.
    def undo_okurigana_start
      with_target_buffer do |buffer|
        buffer.delete_region(@okuri_start_pos, @okuri_start_pos + "*".bytesize)
      end
      @okuri_roman = nil
      @okuri_start_pos = nil
    end

    def cancel_converting
      with_target_buffer do |buffer|
        buffer.delete_region(@marker_pos, buffer.point)
      end
      @phase = :normal
      @roman_buffer = +""
      @okuri_roman = nil
      @okuri_start_pos = nil
      @marker_pos = nil
      Window.echo_area.clear_message
      Window.redisplay
      update_cursor_color
    end

    def commit_converting
      # skk-kakutei records a yomi confirmed as-is in the ▽ mode.
      if @okuri_start_pos.nil? && starts_with_hiragana?(current_yomi)
        record_kakutei_history(current_yomi)
      end
      with_target_buffer do |buffer|
        if @okuri_start_pos
          buffer.delete_region(@okuri_start_pos, @okuri_start_pos + "*".bytesize)
        end
        # Remove the ▽ marker (3 bytes for ▽ in UTF-8)
        marker_end = @marker_pos + "▽".bytesize
        buffer.delete_region(@marker_pos, marker_end)
      end
      @phase = :normal
      @roman_buffer = +""
      @okuri_roman = nil
      @okuri_start_pos = nil
      @marker_pos = nil
      Window.redisplay
      update_cursor_color
    end

    # Reads the yomi/okurigana straight out of the buffer, the way ddskk's
    # skk-set-okurigana slices skk-henkan-key out of the region between its
    # markers, instead of accumulating them in separate variables while
    # converting.
    def current_yomi
      with_target_buffer do |buffer|
        buffer.substring(@marker_pos + "▽".bytesize, @okuri_start_pos || buffer.point)
      end
    end

    def current_okuri_kana
      return nil unless @okuri_start_pos
      with_target_buffer do |buffer|
        buffer.substring(@okuri_start_pos + "*".bytesize, buffer.point)
      end
    end

    # Mirrors ddskk's skk-toggle-characters in the "on" (▽) branch: it
    # converts the yomi to the opposite kana and commits, refusing (as
    # ddskk's skk-error does) while unconfirmed romaji remains. Since
    # okurigana always leaves unconfirmed romaji buffered until its first
    # kana is confirmed (at which point converting phase is left via
    # start_selecting), this naturally also covers -- by refusing -- the
    # only okurigana case reachable here.
    def toggle_yomi_katakana
      unless @roman_buffer.empty?
        message("There remains a kana prefix")
        Window.redisplay
        return
      end

      yomi = current_yomi
      return if yomi.empty?

      # skk-henkan-skk-region-by-func records the yomi before toggling it
      # (and commit_converting records it after, like its skk-kakutei).
      record_kakutei_history(yomi) if starts_with_hiragana?(yomi)
      converted = katakana?(yomi[0]) ? katakana_to_hiragana(yomi) : hiragana_to_katakana(yomi)
      with_target_buffer do |buffer|
        buffer.delete_region(@marker_pos + "▽".bytesize, buffer.point)
        buffer.insert(converted)
      end
      commit_converting
    end

    # Mirrors ddskk's skk-comp (SKK manual section 6.4): completes the yomi
    # from the user dictionary's okuri-nasi keys only, most recently
    # confirmed first. Like skk-insert's
    # (skk-comp (not (eq last-command 'skk-comp-do))), TAB right after
    # TAB/Shift-TAB advances the completion, and otherwise starts a new one.
    def complete_yomi(after_completion)
      return unless @okuri_start_pos.nil?

      # Like skk-comp-do's (skk-kana-cleanup 'force): unconfirmed romaji
      # that is a kana by itself ("n") is confirmed, and anything else is
      # dropped. Typing the romaji already broke any run of completions.
      unless @roman_buffer.empty?
        pending = @roman_buffer
        discard_roman_preview
        insert_kana(converting_kana_for_mode("ん")) if pending == "n"
      end

      if after_completion && @comp_candidates
        advance_completion(1, first: false)
      else
        @comp_prefix = current_yomi
        ensure_user_dictionary_loaded
        # Dictionary keys are always hiragana; like skk-comp-do, search with
        # the yomi in hiragana and show the candidates back in katakana.
        key = @mode == :katakana ? katakana_to_hiragana(@comp_prefix) : @comp_prefix
        candidates =
          if key.empty?
            # skk-comp-from-jisyo gives nothing for an empty yomi; only
            # skk-comp-by-history completes it, from the kakutei history.
            @@kakutei_history.uniq
          else
            # Like skk-comp-search-current-buffer, skip the yomi's own
            # entry: completing to what is already there would change
            # nothing.
            @user_okurinasi.keys.select { |k| k.start_with?(key) && k != key }
          end
        @comp_candidates =
          @mode == :katakana ? candidates.map { |k| hiragana_to_katakana(k) } : candidates
        @comp_index = -1
        advance_completion(1, first: true)
      end
    end

    def complete_yomi_backward(after_completion)
      if after_completion && @comp_candidates
        advance_completion(-1, first: false)
      else
        # Drop any completion from before the yomi was edited, so a TAB
        # right after this starts afresh instead of resuming it.
        reset_completion
        Window.beep
        show_completion_message(
          "No more previous completions for \"#{current_yomi}\""
        )
      end
    end

    # Mirrors ddskk's skk-henkan-off-by-quit taking the skk-comp-do branch:
    # C-g right after a completion, even a failed one, only restores the
    # yomi it started from.
    def cancel_completion
      with_target_buffer do |buffer|
        buffer.delete_region(@marker_pos + "▽".bytesize, buffer.point)
        buffer.insert(@comp_prefix)
      end
      reset_completion
      Window.redisplay
    end

    def show_completion_message(text)
      message(text)
      @comp_message_shown = true
      Window.redisplay
    end

    # Like ddskk's skk-comp-circulate (nil by default), stops at either end
    # instead of wrapping around. FIRST is skk-comp-do's argument of the
    # same name, which picks "No completions" over "No more completions".
    def advance_completion(direction, first:)
      new_index = @comp_index + direction
      if new_index < 0 || new_index >= @comp_candidates.size
        Window.beep
        show_completion_message(
          if direction < 0
            "No more previous completions for \"#{@comp_prefix}\""
          elsif @comp_prefix.empty?
            "No more words in history"
          elsif first
            "No completions for \"#{@comp_prefix}\""
          else
            "No more completions for \"#{@comp_prefix}\""
          end
        )
        return
      end
      @comp_index = new_index
      with_target_buffer do |buffer|
        buffer.delete_region(@marker_pos + "▽".bytesize, buffer.point)
        buffer.insert(@comp_candidates[@comp_index])
      end
      Window.redisplay
    end

    def reset_completion
      @comp_prefix = nil
      @comp_candidates = nil
      @comp_index = nil
    end

    def start_selecting
      reset_completion

      # Snapshot the yomi/okurigana now: once selecting replaces the
      # buffer text with a "▼" candidate, the markers no longer delimit them.
      @yomi = current_yomi
      @okuri_kana = current_okuri_kana

      # Dictionary keys are always hiragana, even when composing in
      # katakana mode (mirrors ddskk's skk-katakana-to-hiragana call in
      # skk-set-okurigana).
      yomi_key = @mode == :katakana ? katakana_to_hiragana(@yomi) : @yomi
      @lookup_key = @okuri_roman ? (yomi_key + @okuri_roman) : yomi_key

      ensure_user_dictionary_loaded
      user_dict = @okuri_roman ? @user_okuriiari : @user_okurinasi
      user_candidates = user_dict[@lookup_key] || []

      base_candidates = if CONFIG[:skk_server_host]
        skk_server_lookup(@lookup_key) || []
      else
        ensure_dictionary_loaded
        dict = @okuri_roman ? @okuriiari : @okurinasi
        dict[@lookup_key] || []
      end

      @base_candidates = base_candidates
      # User dictionary candidates are ordered by recency (see
      # learn_candidate) and take priority, mirroring ddskk's
      # skk-search-prog-list ordering the private dictionary before the
      # system one. Words an skk-ignore-dic-word candidate lists are left
      # out of the system dictionary's candidates.
      user_words = user_candidates.grep_v(IGNORE_DIC_WORD_RE)
      candidates = (user_words + (base_candidates - ignored_words(user_candidates))).uniq

      if candidates.empty?
        register_new_word
        return
      end

      @candidates = candidates
      @candidate_index = 0
      @phase = :selecting

      with_target_buffer do |buffer|
        buffer.delete_region(@marker_pos, buffer.point)
        buffer.insert("▼" + @candidates[0] + (@okuri_kana || ""))
      end
      Window.redisplay
      update_cursor_color
    end

    # Like ddskk, SPC past the last candidate does not wrap around:
    # skk-henkan-1 finds no more candidates, so skk-henkan goes on to
    # skk-henkan-in-minibuff and asks for a new word.
    def next_candidate
      if @candidate_index + 1 >= @candidates.size
        register_new_word
        return
      end
      @candidate_index += 1
      replace_candidate
    end

    # Like skk-previous-candidate with skk-henkan-count 0, "x" on the first
    # candidate goes back to the yomi instead of wrapping around.
    def prev_candidate
      if @candidate_index == 0
        cancel_selecting
        return
      end
      @candidate_index -= 1
      replace_candidate
    end

    def replace_candidate
      with_target_buffer do |buffer|
        buffer.delete_region(@marker_pos, buffer.point)
        buffer.insert("▼" + @candidates[@candidate_index] + (@okuri_kana || ""))
      end
      Window.redisplay
    end

    def confirm_selecting
      confirm_word(@candidates[@candidate_index])
    end

    # Shared by confirm_selecting and register_new_word: insert the final
    # word, learn it into the user dictionary, and leave converting/
    # selecting entirely.
    def confirm_word(word)
      with_target_buffer do |buffer|
        buffer.delete_region(@marker_pos, buffer.point)
        buffer.insert(word + (@okuri_kana || ""))
      end
      learn_candidate(word)
      leave_conversion
    end

    # Mirrors ddskk's skk-purge-from-jisyo: once confirmed with yes-or-no-p,
    # remove the current candidate from the user dictionary and delete the
    # ▼ text from the buffer without inserting anything.
    def purge_candidate
      word = @candidates[@candidate_index]
      purge =
        begin
          yes_or_no?("Really purge \"#{@lookup_key} /#{word}/ \"?")
        rescue Quit
          false
        end
      unless purge
        Window.redisplay
        return
      end

      purge_from_user_dictionary(word)
      with_target_buffer do |buffer|
        buffer.delete_region(@marker_pos, buffer.point)
      end
      leave_conversion
    end

    def leave_conversion
      @phase = :normal
      @yomi = +""
      @roman_buffer = +""
      @okuri_roman = nil
      @okuri_start_pos = nil
      @okuri_kana = nil
      @candidates = []
      @candidate_index = 0
      @marker_pos = nil
      Window.redisplay
      update_cursor_color
    end

    # Mirrors ddskk's skk-henkan-in-minibuff: when no candidate is found,
    # or SPC runs past the last one, read a new word for skk-henkan-key from the minibuffer and register
    # it. Unlike ddskk, the minibuffer here is not switched into SKK
    # itself, so entering kanji requires switching input method by hand
    # (e.g. C-\); nested registration (ddskk lets an unresolved word typed
    # inside the registration prompt itself trigger another registration)
    # is left for a follow-up.
    def register_new_word
      # EchoArea#redisplay only ever draws @prompt when @message is nil --
      # otherwise it draws @message instead. A "No conversion: ..." message
      # left over from a previous registration attempt would otherwise
      # blank out this new prompt on screen even though @prompt itself
      # gets set correctly underneath it.
      Window.echo_area.clear_message
      prompt = "SKK register #{@yomi}#{@okuri_roman ? "*#{@okuri_roman}" : ""}: "
      new_word =
        begin
          read_from_minibuffer(prompt)
        rescue Quit
          +""
        end

      if new_word.empty?
        # Registering after the candidates ran out leaves the last one
        # shown, as skk-henkan-in-minibuff puts it back when given an empty
        # string; with no candidates at all there is nothing to go back to.
        message("No conversion: #{@yomi}") unless @phase == :selecting
        Window.redisplay
        return
      end

      confirm_word(new_word)
    end

    # Mirrors ddskk's skk-previous-candidate: cancelling out of the
    # candidate list drops the okurigana distinction entirely (the "*"
    # marker is not restored), so the okurigana text rejoins the yomi as
    # plain, un-marked headword text.
    def cancel_selecting
      with_target_buffer do |buffer|
        buffer.delete_region(@marker_pos, buffer.point)
        buffer.insert("▽" + @yomi + (@okuri_kana || ""))
      end
      @phase = :converting
      @roman_buffer = +""
      @okuri_roman = nil
      @okuri_start_pos = nil
      @candidates = []
      @candidate_index = 0
      Window.redisplay
      update_cursor_color
    end

    def ensure_dictionary_loaded
      return if @okuriiari

      @okuriiari, @okurinasi =
        parse_skk_dictionary(CONFIG[:skk_dictionary_path], encoding: "EUC-JP:UTF-8")
    end

    def ensure_user_dictionary_loaded
      path = CONFIG[:skk_user_dictionary_path]
      @user_okuriiari, @user_okurinasi =
        @@user_dictionaries[path] ||=
          if path && File.exist?(path)
            parse_skk_dictionary(path, encoding: "UTF-8")
          else
            [{}, {}]
          end
    end

    def parse_skk_dictionary(path, encoding:)
      okuriiari = {}
      okurinasi = {}
      section = :okuriiari

      File.foreach(path, encoding: encoding) do |line|
        line.chomp!
        if line == ";; okuri-nasi entries."
          section = :okurinasi
          next
        end
        next if line.start_with?(";") || line.empty?

        key, rest = line.split(" /", 2)
        next unless key && rest

        candidates = rest.split("/").map { |c| c.split(";").first&.strip }.compact.reject(&:empty?)
        next if candidates.empty?

        if section == :okuriiari
          okuriiari[key] = candidates
        else
          okurinasi[key] = candidates
        end
      end

      [okuriiari, okurinasi]
    end

    # Mirrors ddskk's skk-update-jisyo-1: move the confirmed candidate to
    # the front of its entry, and the entry itself to the front of the
    # dictionary (completion walks the keys in that order), then persist
    # immediately, since this SKK implementation has no explicit save
    # command or autosave-count setting yet.
    def learn_candidate(candidate)
      dict = @okuri_roman ? @user_okuriiari : @user_okurinasi
      entries = dict.delete(@lookup_key) || []
      candidates = [candidate] + entries.reject { |c| c == candidate }
      dict.replace({ @lookup_key => candidates }.merge(dict))
      save_user_dictionary
      # skk-update-jisyo records only okuri-nasi conversions in the history.
      record_kakutei_history(@lookup_key) unless @okuri_roman
    end

    # Mirrors the purge branch of ddskk's skk-update-jisyo-1: a word the
    # system dictionary (or SKK server) also has is quoted with
    # skk-ignore-dic-word, folded into one candidate as
    # skk-compose-ignore-word does, so that later conversions hide it;
    # any other word is just deleted. Unlike ddskk's skk-update-jisyo,
    # the yomi is not recorded in the kakutei history.
    def purge_from_user_dictionary(word)
      dict = @okuri_roman ? @user_okuriiari : @user_okurinasi
      entries = (dict.delete(@lookup_key) || []) - [word]
      if @base_candidates.include?(word)
        ignored = ignored_words(entries) + [word]
        quoted = ignored.map { |w| "\"#{w}\"" }.join(" ")
        entries = ["(skk-ignore-dic-word #{quoted})"] + entries.grep_v(IGNORE_DIC_WORD_RE)
      end
      # skk-update-jisyo-1 writes nothing back for an entry left empty.
      dict.replace({ @lookup_key => entries }.merge(dict)) unless entries.empty?
      save_user_dictionary
    end

    def ignored_words(candidates)
      candidates.flat_map { |c|
        m = IGNORE_DIC_WORD_RE.match(c)
        m ? m[1].scan(/"([^"]*)"/).flatten : []
      }
    end

    # Like skk-update-kakutei-history, keeping only the newest
    # KAKUTEI_HISTORY_LIMIT entries.
    def record_kakutei_history(yomi)
      @@kakutei_history.unshift(yomi)
      @@kakutei_history.slice!(KAKUTEI_HISTORY_LIMIT..)
    end

    # The check skk-kakutei and skk-henkan-skk-region-by-func make with
    # skk-what-char-type at the ▽ point before recording a yomi.
    def starts_with_hiragana?(yomi)
      yomi.match?(/\A[ぁ-ん]/)
    end

    def save_user_dictionary
      path = CONFIG[:skk_user_dictionary_path]
      return unless path

      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "w:UTF-8") do |f|
        f.puts ";; okuri-ari entries."
        @user_okuriiari.each do |key, candidates|
          f.puts "#{key} /#{candidates.join('/')}/"
        end
        f.puts ";; okuri-nasi entries."
        @user_okurinasi.each do |key, candidates|
          f.puts "#{key} /#{candidates.join('/')}/"
        end
      end
    end

    def kana_for_mode(hiragana_kana)
      case @mode
      when :hiragana
        hiragana_kana
      when :katakana
        hiragana_to_katakana(hiragana_kana)
      when :hankaku_katakana
        hiragana_to_hankaku_katakana(hiragana_kana)
      else
        hiragana_kana
      end
    end

    def hiragana_to_katakana(kana)
      kana.chars.map { |c|
        c.ord.between?(0x3041, 0x3096) ? (c.ord + 0x60).chr("UTF-8") : c
      }.join
    end

    def katakana_to_hiragana(kana)
      kana.chars.map { |c|
        c.ord.between?(0x30A1, 0x30F6) ? (c.ord - 0x60).chr("UTF-8") : c
      }.join
    end

    def katakana?(char)
      char.ord.between?(0x30A1, 0x30F6)
    end

    def hiragana_to_hankaku_katakana(kana)
      kana.chars.map { |c|
        case c.ord
        when 0x3041 then "ｧ"
        when 0x3042 then "ｱ"
        when 0x3043 then "ｨ"
        when 0x3044 then "ｲ"
        when 0x3045 then "ｩ"
        when 0x3046 then "ｳ"
        when 0x3047 then "ｪ"
        when 0x3048 then "ｴ"
        when 0x3049 then "ｫ"
        when 0x304a then "ｵ"
        when 0x304b then "ｶ"
        when 0x304c then "ｶﾞ"
        when 0x304d then "ｷ"
        when 0x304e then "ｷﾞ"
        when 0x304f then "ｸ"
        when 0x3050 then "ｸﾞ"
        when 0x3051 then "ｹ"
        when 0x3052 then "ｹﾞ"
        when 0x3053 then "ｺ"
        when 0x3054 then "ｺﾞ"
        when 0x3055 then "ｻ"
        when 0x3056 then "ｻﾞ"
        when 0x3057 then "ｼ"
        when 0x3058 then "ｼﾞ"
        when 0x3059 then "ｽ"
        when 0x305a then "ｽﾞ"
        when 0x305b then "ｾ"
        when 0x305c then "ｾﾞ"
        when 0x305d then "ｿ"
        when 0x305e then "ｿﾞ"
        when 0x305f then "ﾀ"
        when 0x3060 then "ﾀﾞ"
        when 0x3061 then "ﾁ"
        when 0x3062 then "ﾁﾞ"
        when 0x3063 then "ｯ"
        when 0x3064 then "ﾂ"
        when 0x3065 then "ﾂﾞ"
        when 0x3066 then "ﾃ"
        when 0x3067 then "ﾃﾞ"
        when 0x3068 then "ﾄ"
        when 0x3069 then "ﾄﾞ"
        when 0x306a then "ﾅ"
        when 0x306b then "ﾆ"
        when 0x306c then "ﾇ"
        when 0x306d then "ﾈ"
        when 0x306e then "ﾉ"
        when 0x306f then "ﾊ"
        when 0x3070 then "ﾊﾞ"
        when 0x3071 then "ﾊﾟ"
        when 0x3072 then "ﾋ"
        when 0x3073 then "ﾋﾞ"
        when 0x3074 then "ﾋﾟ"
        when 0x3075 then "ﾌ"
        when 0x3076 then "ﾌﾞ"
        when 0x3077 then "ﾌﾟ"
        when 0x3078 then "ﾍ"
        when 0x3079 then "ﾍﾞ"
        when 0x307a then "ﾍﾟ"
        when 0x307b then "ﾎ"
        when 0x307c then "ﾎﾞ"
        when 0x307d then "ﾎﾟ"
        when 0x307e then "ﾏ"
        when 0x307f then "ﾐ"
        when 0x3080 then "ﾑ"
        when 0x3081 then "ﾒ"
        when 0x3082 then "ﾓ"
        when 0x3083 then "ｬ"
        when 0x3084 then "ﾔ"
        when 0x3085 then "ｭ"
        when 0x3086 then "ﾕ"
        when 0x3087 then "ｮ"
        when 0x3088 then "ﾖ"
        when 0x3089 then "ﾗ"
        when 0x308a then "ﾘ"
        when 0x308b then "ﾙ"
        when 0x308c then "ﾚ"
        when 0x308d then "ﾛ"
        when 0x308e then "ﾜ"
        when 0x308f then "ﾜ"
        when 0x3090 then "ｲ"
        when 0x3091 then "ｴ"
        when 0x3092 then "ｦ"
        when 0x3093 then "ﾝ"
        else c
        end
      }.join
    end

    def current_table
      case @mode
      when :katakana then KATAKANA_TABLE
      when :hankaku_katakana then HANKAKU_KATAKANA_TABLE
      else HIRAGANA_TABLE
      end
    end

    def current_prefixes
      case @mode
      when :hankaku_katakana then HANKAKU_KATAKANA_PREFIXES
      else HIRAGANA_PREFIXES
      end
    end

    # Unlike current_table/current_prefixes (used by process_romaji for
    # ordinary input), converting only switches to katakana, not hankaku
    # katakana: half-width katakana isn't hiragana-convertible for the
    # dictionary lookup key the way full-width katakana is (see
    # start_selecting), and ddskk's half-width kana input is a separate
    # mode with its own conversion path, not part of skk-katakana.
    def converting_table
      @mode == :katakana ? KATAKANA_TABLE : HIRAGANA_TABLE
    end

    def converting_kana_for_mode(hiragana_kana)
      @mode == :katakana ? hiragana_to_katakana(hiragana_kana) : hiragana_kana
    end

    def update_cursor_color
      return unless STDOUT.tty?
      colors = CONFIG[:skk_cursor_colors] || DEFAULT_CURSOR_COLORS
      color = colors[@mode]
      if color
        STDOUT.write("\e]12;#{color}\a")
      else
        reset_cursor_color
      end
      STDOUT.flush
    end

    def reset_cursor_color
      return unless STDOUT.tty?
      STDOUT.write("\e]112\a")
      STDOUT.flush
    end

    SKK_SERVER_TIMEOUT = 3  # seconds

    def close_skk_server
      return unless @skk_server_socket
      begin
        @skk_server_socket.write("0\n")
      rescue IOError, Errno::EPIPE
      end
      @skk_server_socket.close rescue nil
      @skk_server_socket = nil
    end

    def skk_server_connect
      return true if @skk_server_socket && !@skk_server_socket.closed?
      host = CONFIG[:skk_server_host]
      return false unless host
      port = CONFIG[:skk_server_port] || 1178
      Timeout.timeout(SKK_SERVER_TIMEOUT) do
        @skk_server_socket = TCPSocket.new(host, port)
      end
      true
    end

    def skk_server_lookup(lookup_key)
      skk_server_connect
      begin
        Timeout.timeout(SKK_SERVER_TIMEOUT) do
          @skk_server_socket.write("1#{lookup_key} \n".encode("EUC-JP"))
          response = @skk_server_socket.gets("\n")
          return nil unless response
          response = response.encode("UTF-8", "EUC-JP", invalid: :replace, undef: :replace).chomp
          return nil unless response.start_with?("1/")
          body = response[2..]
          candidates = body.split("/").map { |c| c.split(";").first&.strip }.compact.reject(&:empty?)
          candidates.empty? ? nil : candidates
        end
      rescue Timeout::Error, IOError, Errno::EPIPE, Errno::ECONNRESET
        @skk_server_socket.close rescue nil
        @skk_server_socket = nil
        nil
      end
    end
  end

  SKK_DICTIONARY_URL = "https://github.com/skk-dev/dict/raw/090619ac57ef230a0506c191b569fc8c82b1025b/SKK-JISYO.L"

  module Commands
    define_command(:skk_download_dictionary, doc: "Download SKK dictionary") do
      path = CONFIG[:skk_dictionary_path]
      if File.exist?(path) && !yes_or_no?("#{path} already exists.  Overwrite it?")
        return
      end
      background do
        URI.open(SKK_DICTIONARY_URL) do |f|
          FileUtils.mkdir_p(File.dirname(path))
          File.open(path, "wb") do |out|
            IO.copy_stream(f, out)
          end
        end
        foreground do
          message("Downloaded to #{path}")
        end
      end
    end
  end
end
