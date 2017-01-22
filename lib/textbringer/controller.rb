# frozen_string_literal: true

module Textbringer
  TOP_LEVEL_TAG = Object.new
  RECURSIVE_EDIT_TAG = Object.new

  class Controller
    attr_accessor :this_command, :last_command, :overriding_map
    attr_accessor :prefix_arg, :current_prefix_arg
    attr_reader :last_key

    @@current = nil

    def self.current
      @@current
    end

    def self.current=(controller)
      @@current = controller
    end

    def initialize
      @key_sequence = []
      @last_key = nil
      @recursive_edit_level = 0
      @this_command = nil
      @last_command = nil
      @overriding_map = nil
      @prefix_arg = nil
      @current_prefix_arg = nil
    end

    def command_loop(tag)
      catch(tag) do
        loop do
          begin
            c = Window.current.getch
            Window.echo_area.clear_message
            @last_key = c
            @key_sequence << @last_key
            cmd = key_binding(@key_sequence)
            if cmd.is_a?(Symbol) || cmd.respond_to?(:call)
              @key_sequence.clear
              @this_command = cmd
              @current_prefix_arg = @prefix_arg
              @prefix_arg = nil
              begin
                run_hooks(:pre_command_hook, remove_on_error: true)
                if cmd.is_a?(Symbol)
                  send(cmd)
                else
                  cmd.call
                end
              ensure
                run_hooks(:post_command_hook, remove_on_error: true)
                @last_command = @this_command
                @this_command = nil
              end
            else
              if cmd.nil?
                keys = @key_sequence.map { |c| key_name(c) }.join(" ")
                @key_sequence.clear
                Window.echo_area.show("#{keys} is undefined")
              end
            end
          rescue Exception => e
            handle_exception(e)
          end
          Window.redisplay
        end
      end
    end

    def wait_input(msecs)
      Window.current.wait_input(msecs)
    end

    def read_char
      Window.current.getch
    end

    def received_keyboard_quit?
      while (key = Window.current.getch_nonblock) && key >= 0
        if GLOBAL_MAP.lookup([key]) == :keyboard_quit
          return true
        end
      end
      false
    end

    def recursive_edit
      @recursive_edit_level += 1
      begin
        if command_loop(RECURSIVE_EDIT_TAG)
          raise Quit
        end
      ensure
        @recursive_edit_level -= 1
      end
    end

    private

    def key_name(key)
      case key
      when Integer
        if key < 0x80
          s = Curses.keyname(key)
          case s
          when /\AKEY_(.*)/
            "<#{$1.downcase}>"
          else
            s
          end
        else
          key.chr(Encoding::UTF_8)
        end
      else
        key.to_s
      end
    end

    def key_binding(key_sequence)
      @overriding_map&.lookup(key_sequence) ||
      Buffer.current&.keymap&.lookup(key_sequence) ||
        GLOBAL_MAP.lookup(key_sequence)
    end
  end
end
