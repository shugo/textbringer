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
        case c
        when "■"
          nil
        when "◆"
          bushu_compose
        else
          c
        end
      end
    end

    def bushu_compose
      buffer = Buffer.current
      buffer.save_excursion do
        s = 2.times.map {
          buffer.backward_char
          buffer.char_after
        }.sort.join
        c = BUSHU_TABLE[s]
        if c
          buffer.delete_char(2)
          c
        else
          nil
        end
      end
    end
  end
end

