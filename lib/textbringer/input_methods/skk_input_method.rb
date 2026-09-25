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
      @marker_pos = nil
      @lookup_key = nil
      @okuriiari = nil
      @okurinasi = nil
      @user_okuriiari = nil
      @user_okurinasi = nil
      @skk_server_socket = nil
    end

    def toggle
      super
      if @enabled
        update_cursor_color
      else
        reset_cursor_color
        close_skk_server
      end
    end

    def disable
      super
      reset_cursor_color
      close_skk_server
    end

    def on_activate
      update_cursor_color if @enabled
    end

    def on_deactivate
      reset_cursor_color if @enabled
    end

    def status
      STATUS_NAMES[@mode]
    end

    def handle_event(event)
      case @phase
      when :normal     then handle_normal(event)
      when :converting then handle_converting(event)
      when :selecting  then handle_selecting(event)
      end
    end

    private

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
      if backspace_event?(event)
        backspace_converting
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
        cancel_converting
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

      converted = katakana?(yomi[0]) ? katakana_to_hiragana(yomi) : hiragana_to_katakana(yomi)
      with_target_buffer do |buffer|
        buffer.delete_region(@marker_pos + "▽".bytesize, buffer.point)
        buffer.insert(converted)
      end
      commit_converting
    end

    def start_selecting
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

      # User dictionary candidates are ordered by recency (see
      # learn_candidate) and take priority, mirroring ddskk's
      # skk-search-prog-list ordering the private dictionary before the
      # system one.
      candidates = (user_candidates + base_candidates).uniq

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

    def next_candidate
      @candidate_index = (@candidate_index + 1) % @candidates.size
      replace_candidate
    end

    def prev_candidate
      @candidate_index = (@candidate_index - 1 + @candidates.size) % @candidates.size
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
    # read a new word for skk-henkan-key from the minibuffer and register
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
        message("No conversion: #{@yomi}")
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
      return if @user_okuriiari

      path = CONFIG[:skk_user_dictionary_path]
      if path && File.exist?(path)
        @user_okuriiari, @user_okurinasi = parse_skk_dictionary(path, encoding: "UTF-8")
      else
        @user_okuriiari = {}
        @user_okurinasi = {}
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
    # the front of its entry (most-recently-used order) and persist
    # immediately, since this SKK implementation has no explicit save
    # command or autosave-count setting yet.
    def learn_candidate(candidate)
      dict = @okuri_roman ? @user_okuriiari : @user_okurinasi
      entries = dict[@lookup_key] || []
      dict[@lookup_key] = [candidate] + entries.reject { |c| c == candidate }
      save_user_dictionary
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
