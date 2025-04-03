module Textbringer
  class HangulInputMethod < InputMethod
    KEY_TO_COMPATIBILITY_JAMO = {
      "q" => "ㅂ", "w" => "ㅈ", "e" => "ㄷ", "r" => "ㄱ", "t" => "ㅅ",
      "y" => "ㅛ", "u" => "ㅕ", "i" => "ㅑ", "o" => "ㅐ", "p" => "ㅔ",
      "a" => "ㅁ", "s" => "ㄴ", "d" => "ㅇ", "f" => "ㄹ", "g" => "ㅎ",
      "h" => "ㅗ", "j" => "ㅓ", "k" => "ㅏ", "l" => "ㅣ",
      "z" => "ㅋ", "x" => "ㅌ", "c" => "ㅊ", "v" => "ㅍ", "b" => "ㅠ",
      "n" => "ㅜ", "m" => "ㅡ",
      "Q" => "ㅃ", "W" => "ㅉ", "E" => "ㄸ", "R" => "ㄲ", "T" => "ㅆ",
      "O" => "ㅒ", "P" => "ㅖ"
    }

    COMPATIBILITY_JAMO_TO_FINAL = {
      "ㄱ" => "ᆨ", "ㄲ" => "ᆩ", "ㄳ" => "ᆪ", "ㄴ" => "ᆫ",
      "ㄵ" => "ᆬ", "ㄶ" => "ᆭ", "ㄷ" => "ᆮ", "ㄹ" => "ᆯ",
      "ㄺ" => "ᆰ", "ㄻ" => "ᆱ", "ㄼ" => "ᆲ", "ㄽ" => "ᆳ",
      "ㄾ" => "ᆴ", "ㄿ" => "ᆵ", "ㅀ" => "ᆶ", "ㅁ" => "ᆷ",
      "ㅂ" => "ᆸ", "ㅄ" => "ᆹ", "ㅅ" => "ᆺ", "ㅆ" => "ᆻ",
      "ㅇ" => "ᆼ", "ㅈ" => "ᆽ", "ㅊ" => "ᆾ", "ㅋ" => "ᆿ",
      "ㅌ" => "ᇀ", "ㅍ" => "ᇁ", "ㅎ" => "ᇂ"
    }

    FINAL_TO_INITIAL = {
      "ᆨ" => "ᄀ", "ᆩ" => "ᄁ", "ᆫ" => "ᄂ", "ᆮ" => "ᄃ",
      "ᆯ" => "ᄅ", "ᆷ" => "ᄆ", "ᆸ" => "ᄇ", "ᆺ" => "ᄉ",
      "ᆻ" => "ᄊ", "ᆼ" => "ᄋ", "ᆽ" => "ᄌ", "ᆾ" => "ᄎ",
      "ᆿ" => "ᄏ", "ᇀ" => "ᄐ", "ᇁ" => "ᄑ", "ᇂ" => "ᄒ"
    }

    def status
      "한"
    end

    def handle_event(event)
      return event if !event.is_a?(String)
      jamo = KEY_TO_COMPATIBILITY_JAMO[event]
      return event if jamo.nil?
      with_target_buffer do |buffer|
        prev = buffer.char_before
        if /[\u{3131}-\u{3183}\u{ac00}-\u{d7a3}]/.match?(prev) # jamo or syllables
          decomposed_prev, prev = decompose_prev(prev, jamo)
          if c = compose_hangul(prev, jamo)
            buffer.backward_delete_char
            c = decomposed_prev + c if decomposed_prev
            buffer.insert(c)
            Window.redisplay
            return nil
          end
        end
      end
      jamo
    end

    def decompose_prev(prev, jamo)
      if /[\u{ac00}-\u{d7a3}]/.match?(prev) && # syllables
        /[\u{314f}-\u{3163}]/.match?(jamo) # vowels
        s = prev.unicode_normalize(:nfd)
        if s.size == 3 && (initial = FINAL_TO_INITIAL[s[2]])
          return s[0, 2].unicode_normalize(:nfc), initial
        end
      end
      return nil, prev
    end

    def compose_hangul(prev, jamo)
      # Use NFKC for compatibility jamo
      c = (prev + (COMPATIBILITY_JAMO_TO_FINAL[jamo] || jamo)).
        unicode_normalize(:nfkc)
      c.size == 1 ? c : nil
    end
  end
end
