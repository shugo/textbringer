# frozen_string_literal: true

require "text_bringer/buffer"
require "text_bringer/window"
require "text_bringer/echo_area"
require "curses"

module TextBringer
  class Controller
    def initialize
      @buffer = nil
      @minibuffer = Buffer.new
      @current_buffer = nil
      @window = nil
      @current_window = nil
      @echo_area = nil
      @key_sequence =[]
      @global_map = {}
      @minibuffer_local_map = {}
      @buffer_local_maps = Hash.new(@global_map)
      @buffer_local_maps[@minibuffer] = @minibuffer_local_map
      setup_keys
    end

    def start(args)
      @current_buffer = @buffer = args[0] ? Buffer.open(args[0]) : Buffer.new
      Curses.init_screen
      Curses.noecho
      Curses.raw
      begin
        @current_window = @window =
          TextBringer::Window.new(@buffer, Curses.lines - 1, Curses.cols, 0, 0)
        @echo_area = TextBringer::EchoArea.new(@minibuffer, 1, Curses.cols,
                                               Curses.lines - 1, 0)
        @echo_area.show("Quit by C-x C-c")
        @echo_area.redisplay
        @window.redisplay
        Curses.doupdate
        command_loop
      ensure
        Curses.echo
        Curses.noraw
      end
    end

    private

    def set_key(key_map, key, &command)
      *ks, k = kbd(key)
      ks.inject(key_map) { |map, key|
        map[key] ||= {}
      }[k] = command
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

    def setup_keys
      [@global_map, @minibuffer_local_map].each do |map|
        set_key(map, Curses::KEY_RESIZE) {
          @window.resize(Curses.lines - 1, Curses.cols)
          @echo_area.move(Curses.lines - 1, 0)
          @echo_area.resize(1, Curses.cols)
        }
        set_key(map, Curses::KEY_RIGHT) { @current_buffer.forward_char }
        set_key(map, ?\C-f) { @current_buffer.forward_char }
        set_key(map, Curses::KEY_LEFT) { @current_buffer.backward_char }
        set_key(map, ?\C-b) { @current_buffer.backward_char }
        set_key(map, Curses::KEY_DOWN) { @current_buffer.next_line }
        set_key(map, ?\C-n) { @current_buffer.next_line }
        set_key(map, Curses::KEY_UP) { @current_buffer.previous_line }
        set_key(map, ?\C-p) { @current_buffer.previous_line }
        set_key(map, Curses::KEY_DC) { @current_buffer.delete_char }
        set_key(map, ?\C-d) { @current_buffer.delete_char }
        set_key(map, Curses::KEY_BACKSPACE) { @current_buffer.backward_delete_char }
        set_key(map, ?\C-h) { @current_buffer.backward_delete_char }
        set_key(map, ?\C-a) { @current_buffer.beginning_of_line }
        set_key(map, ?\C-e) { @current_buffer.end_of_line }
        set_key(map, "\e<") { @current_buffer.beginning_of_buffer }
        set_key(map, "\e>") { @current_buffer.end_of_buffer }
        (0x20..0x7e).each do |c|
          set_key(map, c) { @current_buffer.insert(c.chr) }
        end
        set_key(map, ?\t) { @current_buffer.insert("\t") }
        set_key(map, "\C- ") { @current_buffer.set_mark }
        set_key(map, "\ew") { @current_buffer.copy_region }
        set_key(map, ?\C-w) { @current_buffer.kill_region }
        set_key(map, ?\C-k) { @current_buffer.kill_line }
        set_key(map, ?\C-y) { @current_buffer.yank }
      end

      set_key(@global_map, ?\n) { @current_buffer.newline }
      set_key(@global_map, "\C-x\C-c") { exit }
      set_key(@global_map, "\C-x\C-s") { @current_buffer.save }
      set_key(@global_map, "\e:") { eval_expresssion }

      set_key(@minibuffer_local_map, ?\n) { throw(:minibuffer_exit, true) }
      set_key(@minibuffer_local_map, ?\C-g) { throw(:minibuffer_exit, false) }
    end

    def eval_expresssion
      s = read_from_minibuffer("Eval: ")
      return if s.nil?
      begin
        @echo_area.show(eval(s).inspect)
      rescue Exception => e
        @echo_area.show("#{e.class}: #{e}")
      end
    end

    def read_from_minibuffer(prompt)
      buffer = @current_buffer
      window = @current_window
      begin
        @current_buffer = @minibuffer
        @current_buffer.delete_region(0, @current_buffer.size)
        @current_window = @echo_area
        @echo_area.show(prompt)
        @echo_area.redisplay
        Curses.doupdate
        result = if catch(:minibuffer_exit) { command_loop }
                   @minibuffer.to_s.chomp
                 else
                   nil
                 end
        @minibuffer.delete_region(0, @current_buffer.size)
        @echo_area.clear
        @echo_area.redisplay
        Curses.doupdate
        result
      ensure
        @current_buffer = buffer
        @current_window = window
      end
    end

    def command_loop
      while c = @current_window.getch
        if @current_window != @echo_area
          @echo_area.clear
        end
        @key_sequence << c.ord
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
              keys = @key_sequence.map { |c| Curses.keyname(c) }.join(" ")
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
        Curses.doupdate
      end
    end
  end
end
