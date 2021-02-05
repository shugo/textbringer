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
      if @mazegaki_start_pos
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
          start_mazegaki_conversion(false)
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

    def start_mazegaki_conversion(with_inflection = false)
      @mazegaki_convert_with_inflection = with_inflection
      buffer = Buffer.current
      pos = find_mazegaki_start_pos
      mazegaki_convert(pos)
    end

    def mazegaki_convert(pos)
      buffer = Buffer.current
      s = buffer.substring(pos, buffer.point)
      c = mazegaki_lookup(s)
      if c
        candidates = c.split("/").reject(&:empty?)
        buffer.save_excursion do
          buffer.goto_char(pos)
          buffer.insert("△")
          buffer.backward_char
          @mazegaki_start_pos = pos
          @mazegaki_candidates = candidates
          @mazegaki_candidates_page = 0
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

    def find_mazegaki_start_pos
      buffer = Buffer.current
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
      case event
      when " "
        return mazegaki_next_page
      when "<"
        return mazegaki_relimit_left
      when ">"
        return mazegaki_relimit_right
      end
      begin
        buffer = Buffer.current
        if key_index
          mazegaki_limit = MAZEGAKI_STROKE_PRIORITY_LIST.size
          i = MAZEGAKI_STROKE_PRIORITY_LIST.index(key_index)
          offset = @mazegaki_candidates_page * mazegaki_limit + i
          c = @mazegaki_candidates[offset]
          if c
            buffer.delete_region(@mazegaki_start_pos, buffer.point)
            insert(c)
            return nil
          end
        end
        buffer.save_excursion do
          buffer.goto_char(@mazegaki_start_pos)
          buffer.delete_char
        end
        nil
      ensure
        @mazegaki_start_pos = nil
        @mazegaki_candidates = nil
        if @delete_help_window
          Window.delete_window(@help_window)
        elsif @prev_buffer
          @help_window.buffer = @prev_buffer
        end
        @delete_help_window = false
        @help_window = nil
        @prev_buffer = nil
        Window.redisplay
      end
    end

    def mazegaki_next_page
      @mazegaki_candidates_page += 1
      if @mazegaki_candidates_page * mazegaki_limit >
          @mazegaki_candidates.size
        @mazegaki_candidates_page = 0
      end
      show_mazegaki_candidates
      Window.redisplay
      return nil
    end

    def mazegaki_relimit_left
      buffer = Buffer.current
      start_pos = nil
      buffer.save_excursion do
        mark = buffer.new_mark
        begin
          buffer.goto_char(@mazegaki_start_pos)
          buffer.delete_char
          s = buffer.substring(buffer.point, mark.location)
          (MAZEGAKI_MAX_WORD_LEN - s.size).times do
            break if buffer.beginning_of_buffer?
            buffer.backward_char
            s = buffer.substring(buffer.point, mark.location)
            if mazegaki_lookup(s)
              start_pos = buffer.point
              break
            end
          end
          if start_pos.nil?
            buffer.goto_char(@mazegaki_start_pos)
            buffer.insert("△")
            raise EditorError, "Can't relimit left"
          end
        ensure
          mark.delete
        end
      end
      mazegaki_convert(start_pos)
      Window.redisplay
      return nil
    end

    def mazegaki_relimit_right
      buffer = Buffer.current
      start_pos = nil
      buffer.save_excursion do
        mark = buffer.new_mark
        begin
          buffer.goto_char(@mazegaki_start_pos)
          buffer.delete_char
          loop do
            break if buffer.point >= mark.location
            buffer.forward_char
            s = buffer.substring(buffer.point, mark.location)
            if mazegaki_lookup(s)
              start_pos = buffer.point
              break
            end
          end
          if start_pos.nil?
            buffer.goto_char(@mazegaki_start_pos)
            buffer.insert("△")
            raise EditorError, "Can't relimit right"
          end
        ensure
          mark.delete
        end
      end
      mazegaki_convert(start_pos)
      Window.redisplay
      return nil
    end

    def show_mazegaki_candidates
      offset = @mazegaki_candidates_page * mazegaki_limit
      candidates = @mazegaki_candidates[offset, mazegaki_limit]
      xs = Array.new(40, "-")
      candidates.each_with_index do |s, i|
        xs[MAZEGAKI_STROKE_PRIORITY_LIST[i]] = s
      end
      max_width = candidates.map { |s|
        Buffer.display_width(s)
      }.max
      page = @mazegaki_candidates_page + 1
      page_count =
        (@mazegaki_candidates.size.to_f / mazegaki_limit).ceil
      message = xs.map.with_index { |s, i|
        space = " " * (max_width - Buffer.display_width(s))
        if i % 10 < 5
          s + space
        else
          space + s
        end
      }.each_slice(10).map.with_index { |ys, i|
        if i == 0
          " " + ys[0, 4].join(" ") + "  " + ys[4, 2].join("  ") + "  " +
            ys[6, 4].join(" ")
        else
          "[" + ys[0, 4].join(" ") + "] " + ys[4, 2].join("  ") + " [" +
            ys[6, 4].join(" ") + "]"
        end
      }.join("\n") + "   (#{page}/#{page_count})"
      show_help(message)
    end

    def mazegaki_limit
      MAZEGAKI_STROKE_PRIORITY_LIST.size
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
        @delete_help_window = true
      end
      if Window.current.echo_area?
        window = Window.list.last
      else
        windows = Window.list
        i = (windows.index(Window.current) + 1) % windows.size
        window = windows[i]
      end
      @help_window = window
      @prev_buffer = window.buffer
      window.buffer = buffer
    end
  end
end
