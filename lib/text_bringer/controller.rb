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
        @status_message = @status_window << "Quit by ESC"
        @status_window.refresh
        @window.redisplay
        command_loop
      ensure
        Curses.echo
        Curses.noraw
      end
    end

    def command_loop
      while c = @window.getch
        if @status_message
          @status_window.erase
          @status_window.refresh
          @status_message = nil
        end
        begin
          case c
          when ?\e.ord
            exit
          when Curses::KEY_RIGHT, ?\C-f.ord
            @buffer.forward_char
          when Curses::KEY_LEFT, ?\C-b.ord
            @buffer.backward_char
          when Curses::KEY_DOWN, ?\C-n.ord
            @buffer.next_line
          when Curses::KEY_UP, ?\C-p.ord
            @buffer.previous_line
          when Curses::KEY_DC, ?\C-d.ord
            @buffer.delete_char
          when Curses::KEY_BACKSPACE, ?\C-h.ord
            @buffer.backward_delete_char
          when ?\C-a.ord
            @buffer.beginning_of_line
          when ?\C-e.ord
            @buffer.end_of_line
          when String
            @buffer.insert(c)
          when ?\n.ord
            @buffer.insert(?\n)
          else
            if c < 128
              @buffer.insert(c.chr)
            elsif c < 256
              @key_sequence << c
              s = @key_sequence.pack("C*").force_encoding("utf-8")
              if s.valid_encoding?
                @buffer.insert(s)
                @key_sequence = []
              end
            else
              @status_message = @status_window << "KEY:#{c.inspect}"
              @status_window.refresh
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
