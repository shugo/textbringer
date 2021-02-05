module Textbringer
  class TCodeInputMethod < InputMethod
    require_relative "t_code_input_method/tables"

    data_dir = File.expand_path("t_code_input_method", __dir__)
    BUSHU_PATH = File.expand_path("bushu.rev", data_dir)
    BUSHU_DIC = {} unless defined?(BUSHU_DIC)
    MAZEGAKI_PATH = File.expand_path("mazegaki.dic", data_dir)
    MAZEGAKI_DIC = {} unless defined?(MAZEGAKI_DIC)
    MAZEGAKI_MAX_WORD_LEN = 12 # じょうほうしょりがっかい

    def initialize
      super
      @prev_key_index = nil
      setup_dictionaries
    end

    def setup_dictionaries
      if BUSHU_DIC.empty?
        File.open(BUSHU_PATH) do |f|
          f.each_line do |line|
            x, *xs = line.chomp.chars
            BUSHU_DIC[xs.sort.join] = x
          end
        end
      end
      if MAZEGAKI_DIC.empty?
        File.open(MAZEGAKI_PATH) do |f|
          f.each_line do |line|
            x, y = line.split
            MAZEGAKI_DIC[x] = y
          end
        end
      end
    end

    def status
      "あ"
    end

    def handle_event(event)
      key_index = KEY_TABLE[event]
      if @mazegaki_conversion_start_pos
        return process_mazegaki_conversion(event, key_index)
      end
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
        when ?◆
          bushu_compose
        when ?◇
          mazegaki_convert(false)
        when ?◈
          mazegaki_convert(true)
        when ?⑤
          show_stroke
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
        c = BUSHU_DIC[s]
        if c
          buffer.delete_char(2)
          c
        else
          nil
        end
      end
    end
    def mazegaki_convert(with_inflection = false)
      @mazegaki_convert_with_inflection = with_inflection
      buffer = Buffer.current
      pos = find_mazegaki_conversion_start_pos(buffer)
      s = buffer.substring(pos, buffer.point)
      c = mazegaki_lookup(s)
      if c
        candidates = c.split("/").reject(&:empty?)
        if candidates.size == 1
          buffer.delete_region(pos, buffer.point)
          buffer.insert(candidates[0])
          Window.redisplay
          return nil
        end
        buffer.save_excursion do
          buffer.goto_char(pos)
          buffer.insert("△")
          buffer.backward_char
          @mazegaki_conversion_start_pos = pos
          @mazegaki_conversion_candidates = candidates
          @mazegaki_conversion_candidates_page = 0
          show_mazegaki_candidates
        end
      end
      Window.redisplay
      nil
    end

    def mazegaki_lookup(s)
      if @mazegaki_convert_with_inflection
        word = s + "—"
      else
        word = s
      end
      MAZEGAKI_DIC[word]
    end

    def find_mazegaki_conversion_start_pos(buffer)
      buffer.save_excursion do
        pos = buffer.point
        start_pos = nil
        MAZEGAKI_MAX_WORD_LEN.times do
          break if buffer.beginning_of_buffer?
          buffer.backward_char
          s = buffer.substring(buffer.point, pos)
          if mazegaki_lookup(s)
            start_pos = buffer.point
          end
        end
        if start_pos.nil?
          raise EditorError, "No mazegaki conversion candidate"
        end
        start_pos
      end
    end

    def process_mazegaki_conversion(event, key_index)
      if event == " "
        @mazegaki_conversion_candidates_page += 1
        show_mazegaki_candidates
        Window.redisplay
        return nil
      end
      begin
        buffer = Buffer.current
        if key_index
          limit = MAZEGAKI_STROKE_PRIORITY_LIST.size
          i = MAZEGAKI_STROKE_PRIORITY_LIST.index(key_index)
          offset = @mazegaki_conversion_candidates_page * limit + i
          c = @mazegaki_conversion_candidates[offset]
          if c
            buffer.delete_region(@mazegaki_conversion_start_pos, buffer.point)
            insert(c)
            return nil
          end
        end
        buffer.save_excursion do
          buffer.goto_char(@mazegaki_conversion_start_pos)
          buffer.delete_char
        end
        nil
      ensure
        @mazegaki_conversion_start_pos = nil
        @mazegaki_conversion_candidates = nil
        Window.redisplay
      end
    end

    def show_mazegaki_candidates
      limit = MAZEGAKI_STROKE_PRIORITY_LIST.size
      offset = @mazegaki_conversion_candidates_page * limit
      candidates = @mazegaki_conversion_candidates[offset, limit]
      xs = Array.new(40, "-")
      candidates.each_with_index do |s, i|
        xs[MAZEGAKI_STROKE_PRIORITY_LIST[i]] = s
      end
      max_width = candidates.map { |s|
        Buffer.display_width(s)
      }.max
      message = xs.map { |s|
        s + " " * (max_width - Buffer.display_width(s))
      }.each_slice(10).map { |ys|
        ys.join(" ")
      }.join("\n")
      show_help(message)
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
      if x.nil?
        raise EditorError, "Stroke not found"
      end
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
        Window.list.first.split(message.lines.size + 1)
      end
      if Window.current.echo_area?
        window = Window.list.last
      else
        windows = Window.list
        i = (windows.index(Window.current) + 1) % windows.size
        window = windows[i]
      end
      window.buffer = buffer
    end
  end
end
