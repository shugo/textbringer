# frozen_string_literal: true

require "ncursesw"

module Textbringer
  class Keymap
    def initialize
      @map = {}
    end

    def define_key(key, command)
      key_sequence = kbd(key)

      case key_sequence.size
      when 0
        raise ArgumentError, "Empty key"
      when 1
        @map[key_sequence.first] = command
      else
        k, *ks = key_sequence
        (@map[k] ||= Keymap.new).define_key(ks, command)
      end
    end
    alias [] define_key

    def lookup(key_sequence)
      case key_sequence.size
      when 0
        raise ArgumentError, "Empty key"
      when 1
        @map[key_sequence.first]
      else
        k, *ks = key_sequence
        @map[k]&.lookup(ks)
      end
    end

    def handle_undefined_key
      @map.default_proc = Proc.new { |h, k| yield(k) }
    end

    private

    def kbd(key)
      case key
      when Integer, Symbol
        [key]
      when String
        key.unpack("C*")
      when Array
        key
      else
        raise TypeError, "invalid key type #{key.class}"
      end
    end
  end

  GLOBAL_MAP = Keymap.new
  GLOBAL_MAP.define_key(:resize, :resize_window)
  GLOBAL_MAP.define_key(:right, :forward_char)
  GLOBAL_MAP.define_key(?\C-f, :forward_char)
  GLOBAL_MAP.define_key(:left, :backward_char)
  GLOBAL_MAP.define_key(?\C-b, :backward_char)
  GLOBAL_MAP.define_key("\ef", :forward_word)
  GLOBAL_MAP.define_key("\eb", :backward_word)
  GLOBAL_MAP.define_key("\egc", :goto_char)
  GLOBAL_MAP.define_key("\egg", :goto_line)
  GLOBAL_MAP.define_key("\eg\eg", :goto_line)
  GLOBAL_MAP.define_key(:down, :next_line)
  GLOBAL_MAP.define_key(?\C-n, :next_line)
  GLOBAL_MAP.define_key(:up, :previous_line)
  GLOBAL_MAP.define_key(?\C-p, :previous_line)
  GLOBAL_MAP.define_key(:dc, :delete_char)
  GLOBAL_MAP.define_key(?\C-d, :delete_char)
  GLOBAL_MAP.define_key(:backspace, :backward_delete_char)
  GLOBAL_MAP.define_key(?\C-h, :backward_delete_char)
  GLOBAL_MAP.define_key(?\C-a, :beginning_of_line)
  GLOBAL_MAP.define_key(:home, :beginning_of_line)
  GLOBAL_MAP.define_key(?\C-e, :end_of_line)
  GLOBAL_MAP.define_key(:end, :end_of_line)
  GLOBAL_MAP.define_key("\e<", :beginning_of_buffer)
  GLOBAL_MAP.define_key("\e>", :end_of_buffer)
  (0x20..0x7e).each do |c|
    GLOBAL_MAP.define_key(c, :self_insert)
  end
  GLOBAL_MAP.define_key(?\t, :self_insert)
  GLOBAL_MAP.define_key("\C- ", :set_mark)
  GLOBAL_MAP.define_key("\C-x\C-x", :exchange_point_and_mark)
  GLOBAL_MAP.define_key("\ew", :copy_region)
  GLOBAL_MAP.define_key(?\C-w, :kill_region)
  GLOBAL_MAP.define_key(?\C-k, :kill_line)
  GLOBAL_MAP.define_key("\ed", :kill_word)
  GLOBAL_MAP.define_key(?\C-y, :yank)
  GLOBAL_MAP.define_key("\ey", :yank_pop)
  GLOBAL_MAP.define_key(?\C-_, :undo)
  GLOBAL_MAP.define_key("\C-x\C-_", :redo)
  GLOBAL_MAP.define_key("\C-t", :transpose_chars)
  GLOBAL_MAP.define_key(?\n, :newline)
  GLOBAL_MAP.define_key("\C-l", :recenter)
  GLOBAL_MAP.define_key("\C-v", :scroll_up)
  GLOBAL_MAP.define_key(:npage, :scroll_up)
  GLOBAL_MAP.define_key("\ev", :scroll_down)
  GLOBAL_MAP.define_key(:ppage, :scroll_down)
  GLOBAL_MAP.define_key("\C-x0", :delete_window)
  GLOBAL_MAP.define_key("\C-x1", :delete_other_windows)
  GLOBAL_MAP.define_key("\C-x2", :split_window)
  GLOBAL_MAP.define_key("\C-xo", :other_window)
  GLOBAL_MAP.define_key("\C-x\C-c", :exit_textbringer)
  GLOBAL_MAP.define_key("\C-z", :suspend_textbringer)
  GLOBAL_MAP.define_key("\C-x\C-f", :find_file)
  GLOBAL_MAP.define_key("\C-xb", :switch_to_buffer)
  GLOBAL_MAP.define_key("\C-x\C-s", :save_buffer)
  GLOBAL_MAP.define_key("\C-x\C-w", :write_file)
  GLOBAL_MAP.define_key("\C-xk", :kill_buffer)
  GLOBAL_MAP.define_key("\C-x\nf", :set_buffer_file_encoding)
  GLOBAL_MAP.define_key("\C-x\nn", :set_buffer_file_format)
  GLOBAL_MAP.define_key("\ex", :execute_command)
  GLOBAL_MAP.define_key("\e:", :eval_expression)
  GLOBAL_MAP.define_key(?\C-g, :keyboard_quit)
  GLOBAL_MAP.handle_undefined_key do |key|
    if key.is_a?(Integer) && key > 0x80 && key.chr(Encoding::UTF_8)
      :self_insert
    else
      nil
    end
  end

  MINIBUFFER_LOCAL_MAP = Keymap.new
  MINIBUFFER_LOCAL_MAP.define_key(?\n, :exit_recursive_edit)
  MINIBUFFER_LOCAL_MAP.define_key(?\t, :complete_minibuffer)
  MINIBUFFER_LOCAL_MAP.define_key(?\C-g, :abort_recursive_edit)
end
