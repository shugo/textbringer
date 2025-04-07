module Textbringer
  class Window
    FALLBACK_CHARACTERS = {
      # Diacritical marks
      ## https://www.unicode.org/charts/PDF/U0300.pdf
      ## characters combinable with alphabet:
      ## ("\u{0300}".."\u{036f}").filter { |c|
      ##   ("a".."z").any? { |c2|
      ##     "#{c2}#{c}".unicode_normalize(:nfc).size == 1
      ##   }
      ## }
      "̀" => "`",
      "́" => "´",
      "̂" => "ˆ",
      "̃" => "˜",
      "̄" => "¯",
      "̆" => "˘",
      "̇" => "˙",
      "̈" => "¨",
      "̉" => "ˀ",
      "̊" => "˚",
      "̋" => "˝",
      "̌" => "ˇ",
      "̏" => '"',
      "̑" => nil, # combining character only
      "̛" => nil, # combining character only
      "̣" => nil, # combining character only
      "̤" => nil, # combining character only
      "̥" => "˳",
      "̦" => ",",
      "̧" => "¸",
      "̨" => "˛",
      "̭" => nil, # combining character only
      "̮" => nil, # combining character only
      "̰" => nil, # combining character only
      "̱" => "ˍ",
      "̀" => nil, # combining character only
      "́" => nil, # combining character only
      "̈́" => nil, # combining character only

      # Hiragana
      "゙" => "゛",
      "゚" => "゜",

      # Hangul jamo
      ## initial
      "ᄀ" => "ㄱ",
      "ᄁ" => "ㄲ",
      "ᄂ" => "ㄴ",
      "ᄃ" => "ㄷ",
      "ᄄ" => "ㄸ",
      "ᄅ" => "ㄹ",
      "ᄆ" => "ㅁ",
      "ᄇ" => "ㅂ",
      "ᄈ" => "ㅃ",
      "ᄉ" => "ㅅ",
      "ᄊ" => "ㅆ",
      "ᄋ" => "ㅇ",
      "ᄌ" => "ㅈ",
      "ᄍ" => "ㅉ",
      "ᄎ" => "ㅊ",
      "ᄏ" => "ㅋ",
      "ᄐ" => "ㅌ",
      "ᄑ" => "ㅍ",
      "ᄒ" => "ㅎ",
      ## medial
      "ᅡ" => "ㅏ",
      "ᅢ" => "ㅐ",
      "ᅣ" => "ㅑ",
      "ᅤ" => "ㅒ",
      "ᅥ" => "ㅓ",
      "ᅦ" => "ㅔ",
      "ᅧ" => "ㅕ",
      "ᅨ" => "ㅖ",
      "ᅩ" => "ㅗ",
      "ᅪ" => "ㅘ",
      "ᅫ" => "ㅙ",
      "ᅬ" => "ㅚ",
      "ᅭ" => "ㅛ",
      "ᅮ" => "ㅜ",
      "ᅯ" => "ㅝ",
      "ᅰ" => "ㅞ",
      "ᅱ" => "ㅟ",
      "ᅲ" => "ㅠ",
      "ᅳ" => "ㅡ",
      "ᅴ" => "ㅢ",
      "ᅵ" => "ㅣ",
      ## final
      "ᆨ" => "ㄱ",
      "ᆩ" => "ㄲ",
      "ᆪ" => "ㄳ",
      "ᆫ" => "ㄴ",
      "ᆬ" => "ㄵ",
      "ᆭ" => "ㄶ",
      "ᆮ" => "ㄷ",
      "ᆯ" => "ㄹ",
      "ᆰ" => "ㄺ",
      "ᆱ" => "ㄻ",
      "ᆲ" => "ㄼ",
      "ᆳ" => "ㄽ",
      "ᆴ" => "ㄾ",
      "ᆵ" => "ㄿ",
      "ᆶ" => "ㅀ",
      "ᆷ" => "ㅁ",
      "ᆸ" => "ㅂ",
      "ᆹ" => "ㅄ",
      "ᆺ" => "ㅅ",
      "ᆻ" => "ㅆ",
      "ᆼ" => "ㅇ",
      "ᆽ" => "ㅈ",
      "ᆾ" => "ㅊ",
      "ᆿ" => "ㅋ",
      "ᇀ" => "ㅌ",
      "ᇁ" => "ㅍ",
      "ᇂ" => "ㅎ"
    }
  end
end
