# frozen_string_literal: true

require "textbringer/buffer"
require "textbringer/window"
require "textbringer/echo_area"
require "textbringer/keys"
require "textbringer/commands"

module Textbringer
  class Controller
    include Keys
    include Commands

    def initialize
      super
      @buffer = nil
      @minibuffer = Buffer.new
      @current_buffer = nil
      @window = nil
      @current_window = nil
      @echo_area = nil
      @key_sequence = []
      @last_key = nil
      @global_map = {}
      @minibuffer_local_map = {}
      @buffer_local_maps = Hash.new(@global_map)
      @buffer_local_maps[@minibuffer] = @minibuffer_local_map
      setup_keys
    end

    def start(args)
      @current_buffer = @buffer = args[0] ? Buffer.open(args[0]) : Buffer.new
      Window.start do
        @current_window = @window =
          Textbringer::Window.new(@buffer,
                                  Window.lines - 1, Window.columns, 0, 0)
        @echo_area = Textbringer::EchoArea.new(@minibuffer, 1, Window.columns,
                                               Window.lines - 1, 0)
        @echo_area.show("Quit by C-x C-c")
        @echo_area.redisplay
        @window.redisplay
        Window.update
        command_loop
      end
    end

    private

    def set_key(key_map, key, command = nil, &block)
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

    def last_key
      @last_key
    end

    def setup_keys
      [@global_map, @minibuffer_local_map].each do |map|
        set_key(map, KEY_RESIZE) {
          @window.resize(Window.lines - 1, Window.columns)
          @echo_area.move(Window.lines - 1, 0)
          @echo_area.resize(1, Window.columns)
        }
        set_key(map, KEY_RIGHT, :forward_char)
        set_key(map, ?\C-f, :forward_char)
        set_key(map, KEY_LEFT, :backward_char)
        set_key(map, ?\C-b, :backward_char)
        set_key(map, KEY_DOWN, :next_line)
        set_key(map, ?\C-n, :next_line)
        set_key(map, KEY_UP, :previous_line)
        set_key(map, ?\C-p, :previous_line)
        set_key(map, KEY_DC, :delete_char)
        set_key(map, ?\C-d, :delete_char)
        set_key(map, KEY_BACKSPACE, :backward_delete_char)
        set_key(map, ?\C-h, :backward_delete_char)
        set_key(map, ?\C-a, :beginning_of_line)
        set_key(map, KEY_HOME, :beginning_of_line)
        set_key(map, ?\C-e, :end_of_line)
        set_key(map, KEY_END, :end_of_line)
        set_key(map, "\e<", :beginning_of_buffer)
        set_key(map, "\e>", :end_of_buffer)
        (0x20..0x7e).each do |c|
          set_key(map, c, :self_insert)
        end
        set_key(map, ?\t, :self_insert)
        set_key(map, "\C- ", :set_mark)
        set_key(map, "\ew", :copy_region)
        set_key(map, ?\C-w, :kill_region)
        set_key(map, ?\C-k, :kill_line)
        set_key(map, ?\C-y, :yank)
      end

      set_key(@global_map, ?\n, :newline)
      set_key(@global_map, "\C-v", :scroll_up)
      set_key(@global_map, KEY_NPAGE, :scroll_up)
      set_key(@global_map, "\ev", :scroll_down)
      set_key(@global_map, KEY_PPAGE, :scroll_down)
      set_key(@global_map, "\C-x\C-c") { exit }
      set_key(@global_map, "\C-x\C-s", :save_buffer)
      set_key(@global_map, "\ex", :execute_command)
      set_key(@global_map, "\e:", :eval_expression)

      set_key(@minibuffer_local_map, ?\n) { throw(:minibuffer_exit, true) }
      set_key(@minibuffer_local_map, ?\C-g) { throw(:minibuffer_exit, false) }
    end

    def message(msg)
      @echo_area.show(msg)
    end

    def read_from_minibuffer(prompt)
      buffer = @current_buffer
      window = @current_window
      begin
        @current_buffer = @minibuffer
        @current_buffer.delete_region(0, @current_buffer.size)
        @current_window = @echo_area
        @echo_area.prompt = prompt
        @echo_area.redisplay
        Window.update
        result = if catch(:minibuffer_exit) { command_loop }
                   @minibuffer.to_s.chomp
                 else
                   nil
                 end
        @echo_area.clear
        @echo_area.redisplay
        Window.update
        result
      ensure
        @current_buffer = buffer
        @current_window = window
      end
    end

    def command_loop
      while c = @current_window.getch
        @echo_area.clear_message
        @last_key = c.ord
        @key_sequence << @last_key
        cmd = key_binding(@buffer_local_maps[@current_buffer], @key_sequence)
        begin
          if cmd.respond_to?(:call)
            @key_sequence.clear
            cmd.call
          else
            if @key_sequence.all? { |c| 0x80 <= c && c <= 0xff }
              s = @key_sequence.pack("C*").force_encoding("utf-8")
              if s.valid_encoding?
                @key_sequence.clear
                @current_buffer.insert(s)
              end
            elsif cmd.nil?
              keys = @key_sequence.map { |c| key_name(c) }.join(" ")
              @key_sequence.clear
              @echo_area.show("#{keys} is undefined")
            end
          end
        rescue => e
          @echo_area.show(e.to_s.chomp)
        end
        if @current_window != @echo_area
          @echo_area.redisplay
        end
        @current_window.redisplay
        Window.update
      end
    end
  end
end
