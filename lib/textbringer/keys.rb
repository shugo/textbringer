# frozen_string_literal: true

require "curses"

module Textbringer
  module Keys
    def initialize(*args)
      super
      @global_map = {}
      @minibuffer_local_map = {}
      @buffer_local_maps = Hash.new(@global_map)
      @buffer_local_maps[@minibuffer] = @minibuffer_local_map
      [@global_map, @minibuffer_local_map].each do |map|
        define_key(map, KEY_RESIZE) {
          @window.resize(Window.lines - 1, Window.columns)
          @echo_area.move(Window.lines - 1, 0)
          @echo_area.resize(1, Window.columns)
        }
        define_key(map, KEY_RIGHT, :forward_char)
        define_key(map, ?\C-f, :forward_char)
        define_key(map, KEY_LEFT, :backward_char)
        define_key(map, ?\C-b, :backward_char)
        define_key(map, KEY_DOWN, :next_line)
        define_key(map, ?\C-n, :next_line)
        define_key(map, KEY_UP, :previous_line)
        define_key(map, ?\C-p, :previous_line)
        define_key(map, KEY_DC, :delete_char)
        define_key(map, ?\C-d, :delete_char)
        define_key(map, KEY_BACKSPACE, :backward_delete_char)
        define_key(map, ?\C-h, :backward_delete_char)
        define_key(map, ?\C-a, :beginning_of_line)
        define_key(map, KEY_HOME, :beginning_of_line)
        define_key(map, ?\C-e, :end_of_line)
        define_key(map, KEY_END, :end_of_line)
        define_key(map, "\e<", :beginning_of_buffer)
        define_key(map, "\e>", :end_of_buffer)
        (0x20..0x7e).each do |c|
          define_key(map, c, :self_insert)
        end
        define_key(map, ?\t, :self_insert)
        define_key(map, "\C- ", :set_mark)
        define_key(map, "\ew", :copy_region)
        define_key(map, ?\C-w, :kill_region)
        define_key(map, ?\C-k, :kill_line)
        define_key(map, ?\C-y, :yank)
        define_key(map, ?\C-_, :undo)
        define_key(map, "\C-x\C-_", :redo)
      end

      define_key(@global_map, ?\n, :newline)
      define_key(@global_map, "\C-v", :scroll_up)
      define_key(@global_map, KEY_NPAGE, :scroll_up)
      define_key(@global_map, "\ev", :scroll_down)
      define_key(@global_map, KEY_PPAGE, :scroll_down)
      define_key(@global_map, "\C-x\C-c") { exit }
      define_key(@global_map, "\C-x\C-s", :save_buffer)
      define_key(@global_map, "\ex", :execute_command)
      define_key(@global_map, "\e:", :eval_expression)

      define_key(@minibuffer_local_map, ?\n, :exit_minibuffer)
      define_key(@minibuffer_local_map, ?\C-g, :keyboard_quit)
    end

    Curses.constants.grep(/\AKEY_/) do |name|
      const_set(name, Curses.const_get(name))
    end

    def key_name(key)
      Curses.keyname(key)
    end

    def define_key(key_map, key, command = nil, &block)
      *ks, k = kbd(key)
      
      block ||= Proc.new { send(command) }
      ks.inject(key_map) { |map, key|
        map[key] ||= {}
      }[k] = block
    end

    def kbd(key)
      case key
      when Integer
        [key]
      when String
        key.unpack("C*")
      else
        raise TypeError, "invalid key type #{key.class}"
      end
    end

    def key_binding(key_map, key_sequence)
      key_sequence.inject(key_map) { |map, key|
        return nil if map.nil?
        map[key]
      }
    end
  end
end
