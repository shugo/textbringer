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
        when ?■
          nil
        when ?⑤
          show_stroke
        when ?◆
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


    def show_stroke
      c = Buffer.current.char_after
      x, y = KANJI_TABLE.find.with_index { |row, i|
        j = row.index(c)
        if j
          break [j, i]
        else
          false
        end
      }
      s = "　" * 10 + "・・・・　　・・・・" * 3
      s[x] = "１"
      s[y] = "２"
      message = s.gsub(/.{10}/, "\\&\n").gsub(/　/, "  ")
      show_help(message)
      Window.redisplay
      nil
    end

    def show_help(message)
      buffer = Buffer.find_or_new("*T-Code Help*",
                                  undo_limit: 0, read_only: true)
      buffer.read_only_edit do
        buffer.clear
        buffer.insert(message)
        buffer.beginning_of_buffer
      end
      if Window.list.size == 1
        split_window
        # shrink_window(Window.current.lines - 8)
      end
      windows = Window.list
      i = (windows.index(Window.current) + 1) % windows.size
      windows[i].buffer = buffer
    end
  end
end

