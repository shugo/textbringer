# frozen_string_literal: true

module Textbringer
  module Utils
    def message(msg, log: true, sit_for: nil, sleep_for: nil)
      if log && Buffer.current.name != "*Messages*"
        buffer = Buffer["*Messages*"] ||
          Buffer.new_buffer("*Messages*", undo_limit: 0).tap { |b|
            b[:top_of_window] = b.new_mark
        }
        buffer.read_only = false
        begin
          buffer.end_of_buffer
          buffer.insert(msg + "\n")
          if buffer.current_line > 1000
            buffer.beginning_of_buffer
            10.times do
              buffer.next_line
            end
            buffer.delete_region(buffer.point_min, buffer.point)
            buffer.end_of_buffer
          end
        ensure
          buffer.read_only = true
        end
      end
      Window.echo_area.show(msg)
      if sit_for
        sit_for(sit_for)
        Window.echo_area.clear_message
      end
      if sleep_for
        sleep_for(sleep_for)
        Window.echo_area.clear_message
      end
    end

    def sit_for(secs, no_redisplay = false)
      Window.redisplay unless no_redisplay
      Controller.current.wait_input((secs * 1000).to_i)
    end

    def sleep_for(secs)
      sleep(secs)
    end

    def read_char
      Controller.current.read_char
    end

    def received_keyboard_quit?
      Controller.current.received_keyboard_quit?
    end

    def handle_exception(e)
      if e.is_a?(SystemExit)
        raise
      end
      if Buffer.current.name != "*Backtrace*"
        buffer = Buffer.find_or_new("*Backtrace*", undo_limit: 0)
        if !buffer.mode.is_a?(BacktraceMode)
          buffer.apply_mode(BacktraceMode)
        end
        buffer.read_only = false
        begin
          buffer.delete_region(buffer.point_min, buffer.point_max)
          buffer.insert("#{e.class}: #{e}\n")
          e.backtrace.each do |line|
            buffer.insert(line + "\n")
          end
          buffer.beginning_of_buffer
        ensure
          buffer.read_only = true
        end
      end
      message(e.to_s.chomp)
      Window.beep
    end

    def read_from_minibuffer(prompt, completion_proc: nil, default: nil,
                             keymap: MINIBUFFER_LOCAL_MAP)
      if Window.echo_area.active?
        raise EditorError,
          "Command attempted to use minibuffer while in minibuffer"
      end
      old_buffer = Buffer.current
      old_window = Window.current
      old_completion_proc = Buffer.minibuffer[:completion_proc]
      old_current_prefix_arg = Controller.current.current_prefix_arg
      old_minibuffer_map = Buffer.minibuffer.keymap
      Buffer.minibuffer.keymap = keymap
      Buffer.minibuffer[:completion_proc] = completion_proc
      Window.echo_area.active = true
      begin
        Buffer.minibuffer.delete_region(Buffer.minibuffer.point_min,
                                        Buffer.minibuffer.point_max)
        Window.current = Window.echo_area
        if default
          prompt = prompt.sub(/:/, " (default #{default}):")
        end
        Window.echo_area.prompt = prompt
        Window.echo_area.redisplay
        Window.update
        recursive_edit
        s = Buffer.minibuffer.to_s.chomp
        if default && s.empty?
          default
        else
          s
        end
      ensure
        Window.echo_area.clear
        Window.echo_area.redisplay
        Window.update
        Window.echo_area.active = false
        Window.current = old_window
        # Just in case old_window has been deleted by resize,
        # in which case Window.current is set to the first window.
        Window.current.buffer = Buffer.current = old_buffer
        Buffer.minibuffer[:completion_proc] = old_completion_proc
        Buffer.minibuffer.keymap = old_minibuffer_map
        Controller.current.current_prefix_arg = old_current_prefix_arg
      end
    end

    def read_file_name(prompt, default: nil)
      f = ->(s) {
        s = File.expand_path(s) if s.start_with?("~")
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
      file = read_from_minibuffer(prompt, completion_proc: f, default: default)
      File.expand_path(file)
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
          message("Please answer yes or no.", sit_for: 2)
        end
      }
    end

    Y_OR_N_MAP = Keymap.new
    Y_OR_N_MAP.define_key(?y, :self_insert_and_exit_minibuffer)
    Y_OR_N_MAP.define_key(?n, :self_insert_and_exit_minibuffer)
    Y_OR_N_MAP.define_key(?\C-g, :abort_recursive_edit)
    Y_OR_N_MAP.handle_undefined_key do |key|
      :exit_recursive_edit
    end

    def self_insert_and_exit_minibuffer
      self_insert
      exit_recursive_edit
    end

    def y_or_n?(prompt)
      new_prompt = prompt + " (y or n) "
      prompt_modified = false
      loop do
        s = read_from_minibuffer(new_prompt, keymap: Y_OR_N_MAP)
        case s
        when ?y
          break true
        when ?n
          break false
        else
          unless prompt_modified
            new_prompt.prepend("Answer y or n. ")
            prompt_modified = true
          end
        end
      end
    end

    def read_single_char(prompt, chars)
      map = Keymap.new
      chars.each do |c|
        map.define_key(c, :self_insert_and_exit_minibuffer)
      end
      map.define_key(?\C-g, :abort_recursive_edit)
      char_options = chars.join(?/)
      map.handle_undefined_key do |key|
        -> { message("Invalid key.  Type C-g to quit.", sit_for: 2) }
      end
      read_from_minibuffer(prompt + " (#{char_options}) ", keymap: map)
    end

    HOOKS = Hash.new { |h, k| h[k] = [] }

    def add_hook(name, func)
      HOOKS[name].unshift(func)
    end

    def remove_hook(name, func)
      HOOKS[name].delete(func)
    end

    def run_hooks(name, remove_on_error: false)
      HOOKS[name].delete_if do |func|
        begin
          case func
          when Symbol
            send(func)
          else
            func.call
          end
          false
        rescue Exception => e
          raise if e.is_a?(SystemExit)
          if remove_on_error
            true
          else
            raise
          end
        end
      end
    end

    def set_transient_map(map)
      old_overriding_map = Controller.current.overriding_map
      hook = -> {
        Controller.current.overriding_map = old_overriding_map
        remove_hook(:pre_command_hook, hook)
      }
      add_hook(:pre_command_hook, hook)
      Controller.current.overriding_map = map
    end

    def save_excursion(&block)
      buffer = Buffer.current
      begin
        buffer.save_excursion(&block)
      ensure
        Buffer.current = buffer
      end
    end
  end
end
