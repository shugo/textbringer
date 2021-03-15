module Textbringer
  class TCodeInputMethod < InputMethod
    require_relative "t_code_input_method/tables"

    data_dir = File.expand_path("t_code_input_method", __dir__)
    BUSHU_PATH = File.expand_path("bushu.rev", data_dir)
    BUSHU_DIC = {} unless defined?(BUSHU_DIC)
    MAZEGAKI_PATH = File.expand_path("mazegaki.dic", data_dir)
    SKK_JISYO_PATH = File.expand_path("SKK-JISYO.L", data_dir)
    MAZEGAKI_DIC = {} unless defined?(MAZEGAKI_DIC)
    MAZEGAKI_MAX_WORD_LEN = 12 # じょうほうしょりがっかい
    MAZEGAKI_MAX_SUFFIX_LEN = 4

    def initialize
      super
      @prev_key_index = nil
      @mazegaki_start_pos = nil
      @mazegaki_candidates = nil
      @delete_help_window = false
      @help_window = nil
      @prev_buffer = nil
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
        File.open(SKK_JISYO_PATH) do |f|
          f.each_line do |line|
            next if /^;/.match?(line)
            x, y = line.split
            key = x.sub(/\A(\p{hiragana}+)[a-z]\z/, "\\1—")
            MAZEGAKI_DIC[key] ||= y
          end
        end
      end
    end

    def status
      "漢"
    end

    def handle_event(event)
      key_index = KEY_TABLE[event]
      if @mazegaki_start_pos
        if process_mazegaki_conversion(event, key_index)
          return nil
        end
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
          start_mazegaki_conversion(true)
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
      pos, yomi = find_mazegaki_start_pos(with_inflection)
      if pos.nil?
        raise EditorError, "No mazegaki conversion candidate"
      end
      mazegaki_convert(pos, yomi)
    end

    def mazegaki_convert(pos, yomi)
      buffer = Buffer.current
      candidates = mazegaki_lookup_candidates(yomi)
      if candidates
        @mazegaki_yomi = yomi
        @mazegaki_suffix = buffer.substring(pos + yomi.bytesize, buffer.point)
        case candidates.size
        when 1
          buffer.composite_edit do
            buffer.delete_region(pos, buffer.point)
            buffer.insert("△" + candidates[0] + @mazegaki_suffix)
          end
        when 2
          buffer.composite_edit do
            buffer.delete_region(pos, buffer.point)
            buffer.insert("△{" + candidates.join(",") + "}" + @mazegaki_suffix)
          end
        else
          buffer.save_excursion do
            buffer.goto_char(pos)
            buffer.insert("△")
          end
        end
        @mazegaki_start_pos = pos
        @mazegaki_candidates = candidates
        @mazegaki_candidates_page = 0
        if candidates.size > 2
          show_mazegaki_candidates
        end
      end
      Window.redisplay
      nil
    end

    def mazegaki_lookup_yomi(s, with_inflectin)
      if !with_inflectin
        return MAZEGAKI_DIC.key?(s) ? s : nil
      end
      yomi = s.dup
      (MAZEGAKI_MAX_SUFFIX_LEN + 1).times do
        return yomi if MAZEGAKI_DIC.key?(yomi + "—")
        break if !yomi.sub!(/\p{hiragana}\z/, "")
      end
      nil
    end

    def mazegaki_lookup_candidates(yomi)
      if @mazegaki_convert_with_inflection
        s = yomi + "—"
      else
        s = yomi
      end
      c = MAZEGAKI_DIC[s]
      return nil if c.nil?
      candidates = c.split("/").map { |i|
        i.sub(/;.*/, "")
      }.reject(&:empty?)
      return nil if candidates.empty?
      candidates
    end

    def find_mazegaki_start_pos(with_inflection)
      buffer = Buffer.current
      buffer.save_excursion do
        pos = buffer.point
        start_pos = nil
        yomi = nil
        MAZEGAKI_MAX_WORD_LEN.times do
          break if buffer.beginning_of_buffer?
          buffer.backward_char
          s = buffer.substring(buffer.point, pos)
          y = mazegaki_lookup_yomi(s, with_inflection)
          if y
            start_pos = buffer.point
            yomi = y
          end
        end
        return start_pos, yomi
      end
    end

    def process_mazegaki_conversion(event, key_index)
      case event
      when " "
        mazegaki_next_page
        return true
      when "<"
        mazegaki_relimit_left
        return true
      when ">"
        mazegaki_relimit_right
        return true
      end
      begin
        if @mazegaki_candidates.size == 1
          if event == "\C-m"
            mazegaki_finish(@mazegaki_candidates[0])
            return true
          elsif key_index
            mazegaki_finish(@mazegaki_candidates[0])
            return false
          end
        elsif key_index
          mazegaki_limit = MAZEGAKI_STROKE_PRIORITY_LIST.size
          i = MAZEGAKI_STROKE_PRIORITY_LIST.index(key_index)
          if i
            offset = @mazegaki_candidates_page * mazegaki_limit + i
            c = @mazegaki_candidates[offset]
            if c
              mazegaki_finish(c)
              return true
            end
          end
        end
        mazegaki_reset
        true
      ensure
        @mazegaki_start_pos = nil
        @mazegaki_candidates = nil
        Window.redisplay
      end
    end

    def mazegaki_reset
      buffer = Buffer.current
      buffer.undo
      pos = @mazegaki_start_pos +
        @mazegaki_yomi.bytesize + @mazegaki_suffix.bytesize
      buffer.goto_char(pos)
      hide_help_window
    end

    def mazegaki_finish(s)
      mazegaki_reset
      buffer = Buffer.current
      buffer.composite_edit do
        buffer.delete_region(@mazegaki_start_pos, buffer.point)
        buffer.insert(s + @mazegaki_suffix)
      end
    end

    def hide_help_window
      if @delete_help_window
        Window.delete_window(@help_window)
      elsif @prev_buffer
        @help_window.buffer = @prev_buffer
      end
      @delete_help_window = false
      @help_window = nil
      @prev_buffer = nil
    end

    def mazegaki_next_page
      if @mazegaki_candidates.size <= mazegaki_limit
        return
      end
      @mazegaki_candidates_page += 1
      if @mazegaki_candidates_page * mazegaki_limit >
          @mazegaki_candidates.size
        @mazegaki_candidates_page = 0
      end
      show_mazegaki_candidates
      Window.redisplay
    end

    def mazegaki_relimit_left
      buffer = Buffer.current
      yomi = nil
      start_pos = nil
      mazegaki_reset
      buffer.save_excursion do
        pos = buffer.point
        buffer.goto_char(@mazegaki_start_pos)
        s = buffer.substring(buffer.point, pos)
        (MAZEGAKI_MAX_WORD_LEN - s.size).times do
          break if buffer.beginning_of_buffer?
          buffer.backward_char
          s = buffer.substring(buffer.point, pos)
          yomi = mazegaki_lookup_yomi(s, @mazegaki_convert_with_inflection)
          if yomi
            start_pos = buffer.point
            break
          end
        end
        if start_pos.nil?
          message("Can't relimit left")
          start_pos = @mazegaki_start_pos
          yomi = @mazegaki_yomi
        end
      end
      mazegaki_convert(start_pos, yomi)
      Window.redisplay
    end

    def mazegaki_relimit_right
      buffer = Buffer.current
      start_pos = nil
      yomi = nil
      mazegaki_reset
      buffer.save_excursion do
        pos = buffer.point
        buffer.goto_char(@mazegaki_start_pos)
        loop do
          break if buffer.point >= pos
          buffer.forward_char
          s = buffer.substring(buffer.point, pos)
          yomi = mazegaki_lookup_yomi(s, @mazegaki_convert_with_inflection)
          if yomi
            start_pos = buffer.point
            break
          end
        end
      end
      if start_pos.nil?
        if !@mazegaki_convert_with_inflection
          start_pos, yomi = find_mazegaki_start_pos(true)
          if start_pos
            @mazegaki_convert_with_inflection = true
          end
        end
        if start_pos.nil?
          message("Can't relimit right")
          start_pos = @mazegaki_start_pos
          yomi = @mazegaki_yomi
        end
      end
      mazegaki_convert(start_pos, yomi)
      Window.redisplay
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
      if window.buffer != buffer
        @prev_buffer = window.buffer
        window.buffer = buffer
      end
    end
  end
end
