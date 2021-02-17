module Textbringer
  class HiraganaInputMethod < InputMethod
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
      "nn" => "ん"
    }
    HIRAGANA_PREFIXES = HIRAGANA_TABLE.keys.flat_map { |s|
      (s.size - 1).times.map { |i| s[0, i + 1] }
    }.uniq

    def initialize
      super
      @input_buffer = ""
    end

    def status
      "あ"
    end

    def handle_event(event)
      if !event.is_a?(String)
        if !@input_buffer.empty?
          @input_buffer = ""
        end
        return event
      end
      @input_buffer << event
      s = HIRAGANA_TABLE[@input_buffer]
      if s
        return flush(s)
      end
      if HIRAGANA_PREFIXES.include?(@input_buffer)
        return nil
      end
      flush(@input_buffer)
    end

    def flush(s)
      if !@input_buffer.empty?
        @input_buffer = ""
      end
      if s.size == 1
        s
      else
        Buffer.current.insert(s)
        Window.redisplay
        nil
      end
    end
  end
end
