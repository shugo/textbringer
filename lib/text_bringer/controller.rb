# frozen_string_literal: true

require "text_bringer/buffer"
require "text_bringer/window"
require "curses"

module TextBringer
  class Controller
    def initialize
      @buffer = TextBringer::Buffer.new
      @window = nil
      @key_sequence =[]
      @key_map = {}
      setup_keys
    end

    def start(args)
      if args.size > 0
        @buffer.insert(File.read(args[0]))
        @buffer.beginning_of_buffer
      end
      Curses.init_screen
      Curses.noecho
      Curses.raw
      begin
        @window = TextBringer::Window.new(@buffer,
                                          Curses.lines - 1, Curses.cols, 0, 0)
        @status_window = Curses::Window.new(1, Curses.cols, Curses.lines - 1, 0)
        @status_message = @status_window << "Quit by C-x C-c"
        @status_window.refresh
        @window.redisplay
        command_loop
      ensure
        Curses.echo
        Curses.noraw
      end
    end

    private

    def set_key(key, &command)
      *ks, k = kbd(key)
      ks.inject(@key_map) { |map, key|
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

    def key_binding(key_sequence)
      key_sequence.inject(@key_map) { |map, key| map[key] }
    end

    def setup_keys
      set_key("\C-x\C-c") { exit }
      set_key(Curses::KEY_RIGHT) { @buffer.forward_char }
      set_key(?\C-f) { @buffer.forward_char }
      set_key(Curses::KEY_LEFT) { @buffer.backward_char }
      set_key(?\C-b) { @buffer.backward_char }
      set_key(Curses::KEY_DOWN) { @buffer.next_line }
      set_key(?\C-n) { @buffer.next_line }
      set_key(Curses::KEY_UP) { @buffer.previous_line }
      set_key(?\C-p) { @buffer.previous_line }
      set_key(Curses::KEY_DC) { @buffer.delete_char }
      set_key(?\C-d) { @buffer.delete_char }
      set_key(Curses::KEY_BACKSPACE) { @buffer.backward_delete_char }
      set_key(?\C-h) { @buffer.backward_delete_char }
      set_key(?\C-a) { @buffer.beginning_of_line }
      set_key(?\C-e) { @buffer.end_of_line }
      set_key("\e<") { @buffer.beginning_of_buffer }
      set_key("\e>") { @buffer.end_of_buffer }
      (0x20..0x7e).each do |c|
        set_key(c) { @buffer.insert(c.chr) }
      end
      set_key(?\n) { @buffer.insert("\n") }
    end

    def command_loop
      while c = @window.getch
        if @status_message
          @status_window.erase
          @status_window.refresh
          @status_message = nil
        end
        @key_sequence << c.ord
        cmd = key_binding(@key_sequence)
        begin
          if cmd.respond_to?(:call)
            cmd.call
            @key_sequence = []
          else
            if @key_sequence.all? { |c| 0x80 <= c && c <= 0xff }
              s = @key_sequence.pack("C*").force_encoding("utf-8")
              if s.valid_encoding?
                @buffer.insert(s)
                @key_sequence = []
              end
            elsif cmd.nil?
              keys = @key_sequence.map { |c| Curses.keyname(c) }.join(" ")
              @status_message = @status_window << "#{keys} is undefined"
              @status_window.refresh
              @key_sequence = []
            end
          end
        rescue => e
          @status_message = @status_window << e.to_s.chomp
          @status_window.refresh
        end
        @window.redisplay
      end
    end
  end
end
