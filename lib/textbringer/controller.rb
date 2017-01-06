# frozen_string_literal: true

require "textbringer/buffer"
require "textbringer/window"
require "textbringer/echo_area"
require "textbringer/commands"
require "textbringer/keys"

module Textbringer
  class Controller
    include Commands
    include Keys

    def initialize
      @buffer = nil
      @minibuffer = Buffer.new
      @current_buffer = nil
      @window = nil
      @current_window = nil
      @echo_area = nil
      @key_sequence = []
      @last_key = nil
      super
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

    def last_key
      @last_key
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
        catch(:minibuffer_exit) { command_loop(false) }
        @minibuffer.to_s.chomp
      ensure
        @echo_area.clear
        @echo_area.redisplay
        Window.update
        @current_buffer = buffer
        @current_window = window
      end
    end

    def command_loop(catch_keyboard_quit = true)
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
                @current_buffer.insert(s, @last_command == :self_insert)
                @last_command = :self_insert
              end
            elsif cmd.nil?
              keys = @key_sequence.map { |c| key_name(c) }.join(" ")
              @key_sequence.clear
              @echo_area.show("#{keys} is undefined")
            end
          end
        rescue => e
          if !catch_keyboard_quit && e.is_a?(KeyboardQuit)
            raise
          end
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
