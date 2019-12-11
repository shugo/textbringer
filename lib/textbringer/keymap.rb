class Module
  def define_keymap(name)
    unless const_defined?(name, false)
      const_set(name, Textbringer::Keymap.new)
    end
  end
end

module Textbringer
  class Keymap
    include Enumerable

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
        km = @map[k]
        if km.is_a?(Keymap)
          km.lookup(ks)
        else
          nil
        end
      end
    end

    def each(prefixes = [], &block)
      @map.each do |key, val|
        if val.is_a?(Keymap)
          val.each([*prefixes, key], &block)
        else
          yield([*prefixes, key], val)
        end
      end
    end

    def handle_undefined_key
      @map.default_proc = Proc.new { |h, k| yield(k) }
    end

    def self.key_name(key)
      case key
      when Symbol
        "<#{key}>"
      when " "
        "SPC"
      when "\t"
        "TAB"
      when "\e"
        "ESC"
      when "\C-m"
        "RET"
      when /\A[\0-\x1f\x7f]\z/
        "C-" + (key.ord ^ 0x40).chr.downcase
      else
        key.to_s
      end
    end

    def self.key_sequence_string(key_sequence)
      key_sequence.map { |key| key_name(key) }.join(" ")
    end

    private

    def kbd(key)
      case key
      when Symbol
        [key]
      when String
        key.b.gsub(/[\x80-\xff]/n) { |c| "\e" + (c.ord & 0x7f).chr }.chars
      when Array
        key
      else
        raise TypeError, "invalid key type #{key.class}"
      end
    end
  end

  define_keymap :GLOBAL_MAP
  GLOBAL_MAP.define_key(:resize, :resize_window)
  GLOBAL_MAP.define_key(:right, :forward_char)
  GLOBAL_MAP.define_key(?\C-f, :forward_char)
  GLOBAL_MAP.define_key(:left, :backward_char)
  GLOBAL_MAP.define_key(?\C-b, :backward_char)
  GLOBAL_MAP.define_key("\M-f", :forward_word)
  GLOBAL_MAP.define_key("\M-b", :backward_word)
  GLOBAL_MAP.define_key("\M-gc", :goto_char)
  GLOBAL_MAP.define_key("\M-gg", :goto_line)
  GLOBAL_MAP.define_key("\M-g\M-g", :goto_line)
  GLOBAL_MAP.define_key(:down, :next_line)
  GLOBAL_MAP.define_key(?\C-n, :next_line)
  GLOBAL_MAP.define_key(:up, :previous_line)
  GLOBAL_MAP.define_key(?\C-p, :previous_line)
  GLOBAL_MAP.define_key(:dc, :delete_char)
  GLOBAL_MAP.define_key(?\C-d, :delete_char)
  GLOBAL_MAP.define_key(:backspace, :backward_delete_char)
  GLOBAL_MAP.define_key(?\C-h, :backward_delete_char)
  GLOBAL_MAP.define_key(?\C-?, :backward_delete_char)
  GLOBAL_MAP.define_key(?\C-a, :beginning_of_line)
  GLOBAL_MAP.define_key(:home, :beginning_of_line)
  GLOBAL_MAP.define_key(?\C-e, :end_of_line)
  GLOBAL_MAP.define_key(:end, :end_of_line)
  GLOBAL_MAP.define_key("\M-<", :beginning_of_buffer)
  GLOBAL_MAP.define_key("\M->", :end_of_buffer)
  (?\x20..?\x7e).each do |c|
    GLOBAL_MAP.define_key(c, :self_insert)
  end
  GLOBAL_MAP.define_key(?\t, :self_insert)
  GLOBAL_MAP.define_key(?\C-q, :quoted_insert)
  GLOBAL_MAP.define_key("\C-@", :set_mark_command)
  GLOBAL_MAP.define_key("\C-x\C-@", :pop_global_mark)
  GLOBAL_MAP.define_key("\M-*", :next_global_mark)
  GLOBAL_MAP.define_key("\M-?", :previous_global_mark)
  GLOBAL_MAP.define_key("\C-x\C-x", :exchange_point_and_mark)
  GLOBAL_MAP.define_key("\M-w", :copy_region)
  GLOBAL_MAP.define_key(?\C-w, :kill_region)
  GLOBAL_MAP.define_key(?\C-k, :kill_line)
  GLOBAL_MAP.define_key("\M-d", :kill_word)
  GLOBAL_MAP.define_key(?\C-y, :yank)
  GLOBAL_MAP.define_key("\M-y", :yank_pop)
  GLOBAL_MAP.define_key(?\C-_, :undo)
  GLOBAL_MAP.define_key("\C-xu", :undo)
  GLOBAL_MAP.define_key("\C-x\C-_", :redo_command)
  GLOBAL_MAP.define_key("\C-t", :transpose_chars)
  GLOBAL_MAP.define_key("\C-j", :newline)
  GLOBAL_MAP.define_key("\C-m", :newline)
  GLOBAL_MAP.define_key("\C-o", :open_line)
  GLOBAL_MAP.define_key("\M-m", :back_to_indentation)
  GLOBAL_MAP.define_key("\M-^", :delete_indentation)
  GLOBAL_MAP.define_key("\C-xh", :mark_whole_buffer)
  GLOBAL_MAP.define_key("\M-z", :zap_to_char)
  GLOBAL_MAP.define_key("\C-l", :recenter)
  GLOBAL_MAP.define_key("\C-v", :scroll_up)
  GLOBAL_MAP.define_key(:npage, :scroll_up)
  GLOBAL_MAP.define_key("\M-v", :scroll_down)
  GLOBAL_MAP.define_key(:ppage, :scroll_down)
  GLOBAL_MAP.define_key("\C-x0", :delete_window)
  GLOBAL_MAP.define_key("\C-x1", :delete_other_windows)
  GLOBAL_MAP.define_key("\C-x2", :split_window)
  GLOBAL_MAP.define_key("\C-xo", :other_window)
  GLOBAL_MAP.define_key("\C-x^", :enlarge_window)
  GLOBAL_MAP.define_key("\C-x-", :shrink_window_if_larger_than_buffer)
  GLOBAL_MAP.define_key("\C-x\C-c", :exit_textbringer)
  GLOBAL_MAP.define_key("\C-z", :suspend_textbringer)
  GLOBAL_MAP.define_key("\C-x\C-f", :find_file)
  GLOBAL_MAP.define_key("\C-xb", :switch_to_buffer)
  GLOBAL_MAP.define_key("\C-x\C-b", :list_buffers)
  GLOBAL_MAP.define_key("\C-x\C-s", :save_buffer)
  GLOBAL_MAP.define_key("\C-x\C-w", :write_file)
  GLOBAL_MAP.define_key("\C-xk", :kill_buffer)
  GLOBAL_MAP.define_key("\C-x\C-mf", :set_buffer_file_encoding)
  GLOBAL_MAP.define_key("\C-x\C-mn", :set_buffer_file_format)
  GLOBAL_MAP.define_key("\C-x\C-mr", :revert_buffer_with_encoding)
  GLOBAL_MAP.define_key("\M-.", :find_tag)
  GLOBAL_MAP.define_key("\M-x", :execute_command)
  GLOBAL_MAP.define_key("\M-:", :eval_expression)
  GLOBAL_MAP.define_key(?\C-u, :universal_argument)
  GLOBAL_MAP.define_key(?\C-g, :keyboard_quit)
  GLOBAL_MAP.define_key(?\C-s, :isearch_forward)
  GLOBAL_MAP.define_key(?\C-r, :isearch_backward)
  GLOBAL_MAP.define_key("\M-%", :query_replace_regexp)
  GLOBAL_MAP.define_key("\M-!", :shell_execute)
  GLOBAL_MAP.define_key("\C-xr ", :point_to_register)
  GLOBAL_MAP.define_key("\C-xrj", :jump_to_register)
  GLOBAL_MAP.define_key("\C-xrx", :copy_to_register)
  GLOBAL_MAP.define_key("\C-xrs", :copy_to_register)
  GLOBAL_MAP.define_key("\C-xrg", :insert_register)
  GLOBAL_MAP.define_key("\C-xri", :insert_register)
  GLOBAL_MAP.define_key("\C-xrn", :number_to_register)
  GLOBAL_MAP.define_key("\C-xr+", :increment_register)
  GLOBAL_MAP.define_key("\C-x(", :start_keyboard_macro)
  GLOBAL_MAP.define_key(:f3, :start_keyboard_macro)
  GLOBAL_MAP.define_key("\C-x)", :end_keyboard_macro)
  GLOBAL_MAP.define_key("\C-xe", :end_and_call_keyboard_macro)
  GLOBAL_MAP.define_key(:f4, :end_or_call_keyboard_macro)
  GLOBAL_MAP.define_key("\M-q", :fill_paragraph)
  GLOBAL_MAP.define_key([:f1, "b"], :describe_bindings)
  GLOBAL_MAP.define_key([:f1, "f"], :describe_command)
  GLOBAL_MAP.define_key([:f1, "k"], :describe_key)
  GLOBAL_MAP.define_key("\C-x#", :server_edit_done)
  GLOBAL_MAP.handle_undefined_key do |key|
    if key.is_a?(String) && /[\0-\x7f]/ !~ key
      :self_insert
    else
      nil
    end
  end

  define_keymap :MINIBUFFER_LOCAL_MAP
  MINIBUFFER_LOCAL_MAP.define_key("\C-j", :exit_recursive_edit)
  MINIBUFFER_LOCAL_MAP.define_key("\C-m", :exit_recursive_edit)
  MINIBUFFER_LOCAL_MAP.define_key(?\t, :complete_minibuffer)
  MINIBUFFER_LOCAL_MAP.define_key(?\C-g, :abort_recursive_edit)
end
