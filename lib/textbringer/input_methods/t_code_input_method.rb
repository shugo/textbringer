module Textbringer
  class TCodeInputMethod < InputMethod
    require_relative "t_code_input_method/tables"

    def initialize
      super
      @prev_key_index = nil
    end

    def status
      "あ"
    end

    def handle_event(event)
      key_index = KEY_TABLE[event]
      if key_index.nil?
        @prev_key_index = nil
        return event
      end
      if @prev_key_index.nil?
        @prev_key_index = key_index
        nil
      else
        c = KANJI_TABLE[key_index][@prev_key_index]
        @prev_key_index = nil
        c == "■" ? nil : c
      end
    end
  end
end

