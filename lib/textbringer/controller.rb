# frozen_string_literal: true

module Textbringer
  TOP_LEVEL_TAG = Object.new
  RECURSIVE_EDIT_TAG = Object.new

  class Controller
    attr_accessor :this_command, :last_command, :overriding_map
    attr_accessor :prefix_arg, :current_prefix_arg
    attr_reader :last_key, :recursive_edit_level

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
      @echo_immediately = false
    end

    def command_loop(tag)
      catch(tag) do
        loop do
          begin
            echo_input
            c = read_char
            break if c.nil?
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
                keys = @key_sequence.map { |ch| key_name(ch) }.join(" ")
                @key_sequence.clear
                @prefix_arg = nil
                message("#{keys} is undefined")
              end
            end
          rescue Exception => e
            show_exception(e)
            @prefix_arg = nil
          end
          Window.redisplay
        end
      end
    end

    def wait_input(msecs)
      Window.current.wait_input(msecs)
    end

    def read_char
      Window.current.read_char
    end

    def read_char_nonblock
      Window.current.read_char_nonblock
    end

    def received_keyboard_quit?
      while key = read_char_nonblock
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

    def key_name(key)
      case key
      when Symbol
        "<#{key}>"
      when "\e"
        "ESC"
      when "\n"
        "RET"
      when /\A[\0-\b\v-\x1f\x7f]\z/
        "C-" + (key.ord ^ 0x40).chr.downcase
      else
        key.to_s
      end
    end

    private

    def key_binding(key_sequence)
      @overriding_map&.lookup(key_sequence) ||
      Buffer.current&.keymap&.lookup(key_sequence) ||
        GLOBAL_MAP.lookup(key_sequence)
    end

    def echo_input
      if @prefix_arg || !@key_sequence.empty?
        if !@echo_immediately
          return if wait_input(1000)
        end
        @echo_immediately = true
        s = String.new
        if @prefix_arg
          s << "C-u"
          if @prefix_arg != [4]
            s << "(#{@prefix_arg.inspect})"
          end
        end
        if !@key_sequence.empty?
          s << " " if !s.empty?
          s << @key_sequence.map { |ch| key_name(ch) }.join(" ")
        end
        s << "-"
        Window.echo_area.show(s)
        Window.echo_area.redisplay
        Window.current.window.noutrefresh
        Window.update
      else
        @echo_immediately = false
      end
    end
  end
end
