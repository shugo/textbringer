# frozen_string_literal: true

require "textbringer/buffer"
require "textbringer/window"
require "textbringer/echo_area"
require "textbringer/commands"
require "textbringer/keys"

module Textbringer
  TOP_LEVEL_TAG = Object.new
  RECURSIVE_EDIT_TAG = Object.new

  class Controller
    include Commands
    include Keys

    def initialize
      @minibuffer = Buffer.new
      @minibuffer.keymap = MINIBUFFER_LOCAL_MAP
      @minibuffer_completion_proc = nil
      @window = nil
      @current_window = nil
      @echo_area = nil
      @key_sequence = []
      @last_key = nil
      @recursive_edit_level = 0
      super
    end

    def start(args)
      Window.start do
        @current_window = @window =
          Textbringer::Window.new(Window.lines - 1, Window.columns, 0, 0)
        if args.size > 0
          args.reverse_each do |arg|
            find_file(arg)
          end
        else
          buffer = Buffer.new_buffer("Untitled")
          switch_to_buffer(buffer)
        end
        @echo_area = Textbringer::EchoArea.new(1, Window.columns,
                                               Window.lines - 1, 0)
        @echo_area.buffer = @minibuffer
        @echo_area.show("Type C-x C-c to exit Textbringer")
        @echo_area.redisplay
        @window.redisplay
        Window.update
        load_user_config
        trap(:CONT) do
          @echo_area.redraw
          @window.redraw
          Window.update
        end
        loop do
          command_loop(TOP_LEVEL_TAG)
          redisplay
        end
      end
    end

    def last_key
      @last_key
    end

    def message(msg)
      @echo_area.show(msg)
    end

    def read_from_minibuffer(prompt, completion_proc: nil, default: nil)
      if Buffer.current == @minibuffer
        raise "Command attempted to use minibuffer while in minibuffer"
      end
      buffer = Buffer.current
      window = @current_window
      old_completion_proc = @minibuffer_completion_proc
      @minibuffer_completion_proc = completion_proc
      begin
        @minibuffer.delete_region(@minibuffer.point_min, @minibuffer.point_max)
        Buffer.current = @minibuffer
        @current_window = @echo_area
        if default
          prompt = prompt.sub(/:/, " (default #{default}):")
        end
        @echo_area.prompt = prompt
        @echo_area.redisplay
        Window.update
        recursive_edit
        s = @minibuffer.to_s.chomp
        if default && s.empty?
          default
        else
          s
        end
      ensure
        @echo_area.clear
        @echo_area.redisplay
        Window.update
        Buffer.current = buffer
        @current_window = window
        @minibuffer_completion_proc = old_completion_proc
      end
    end

    def read_file_name(prompt, default: nil)
      f = ->(s) {
        files = Dir.glob(s + "*")
        if files.size > 0
          x, *xs = files
          file = x.size.downto(1).lazy.map { |i|
            x[0, i]
          }.find { |i|
            xs.all? { |j| j.start_with?(i) }
          }
          if file && files.size == 1 &&
             File.directory?(file) && !file.end_with?(?/)
            file + "/"
          else
            file
          end
        else
          nil
        end
      }
      read_from_minibuffer(prompt, completion_proc: f, default: default)
    end

    def complete(s, candidates)
      xs = candidates.select { |i| i.start_with?(s) }
      if xs.size > 0
        y, *ys = xs
        y.size.downto(1).lazy.map { |i|
          y[0, i]
        }.find { |i|
          ys.all? { |j| j.start_with?(i) }
        }
      else
        nil
      end
    end

    def read_buffer(prompt, default: (Buffer.last || Buffer.current)&.name)
      f = ->(s) { complete(s, Buffer.names) }
      read_from_minibuffer(prompt, completion_proc: f, default: default)
    end

    def read_command_name(prompt)
      f = ->(s) {
        complete(s.tr("-", "_"), Commands.list.map(&:to_s))
      }
      read_from_minibuffer(prompt, completion_proc: f)
    end

    def yes_or_no?(prompt)
      loop {
        s = read_from_minibuffer(prompt + " (yes or no) ")
        case s
        when "yes"
          return true
        when "no"
          return false
        else
          message("Please answer yes or no.")
        end
      }
    end

    def y_or_n?(prompt)
      loop {
        s = read_from_minibuffer(prompt + " (y or n) ")
        case s
        when "y"
          return true
        when "n"
          return false
        else
          message("Please answer y or n.")
        end
      }
    end

    def redisplay
      if @current_window != @echo_area
        @echo_area.redisplay
      end
      @current_window.redisplay
      Window.update
    end

    def command_loop(tag)
      catch(tag) do
        loop do
          begin
            c = @current_window.getch
            @echo_area.clear_message
            @last_key = c
            @key_sequence << @last_key
            cmd = key_binding(@key_sequence)
            if cmd.is_a?(Symbol) || cmd.respond_to?(:call)
              @key_sequence.clear
              @this_command = nil
              begin
                if cmd.is_a?(Symbol)
                  send(cmd)
                else
                  cmd.call
                end
              ensure
                @last_command = @this_command || cmd
              end
            else
              if cmd.nil?
                keys = @key_sequence.map { |c| key_name(c) }.join(" ")
                @key_sequence.clear
                @echo_area.show("#{keys} is undefined")
              end
            end
          rescue => e
            @echo_area.show(e.to_s.chomp)
            Window.beep
          end
          redisplay
        end
      end
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

    def load_user_config
      config_file = File.expand_path("~/.tb")
      begin
        load(config_file)
      rescue LoadError
      rescue Exception => e
        message(e.to_s)
      end
    end
  end
end
