# frozen_string_literal: true

module Textbringer
  module Commands
    define_command(:version) do
      message("Textbringer #{Textbringer::VERSION} "\
              "(ruby #{RUBY_VERSION} [#{RUBY_PLATFORM}])")
    end

    define_command(:exit_textbringer) do |status = 0|
      if Buffer.any? { |buffer| /\A\*/ !~ buffer.name && buffer.modified? }
        return unless yes_or_no?("Unsaved buffers exist; exit anyway?")
      end
      exit(status)
    end

    define_command(:suspend_textbringer) do
      Curses.close_screen
      Process.kill(:STOP, $$)
    end

    define_command(:execute_command) do
      |cmd = read_command_name("M-x ").strip.intern|
      unless Commands.list.include?(cmd)
        raise EditorError, "Undefined command: #{cmd}"
      end
      Controller.current.this_command = cmd
      send(cmd)
    end

    define_command(:eval_expression) do
      |s = read_from_minibuffer("Eval: ")|
      result = eval(s, TOPLEVEL_BINDING, "(eval_expression)", 1)
      message(result.inspect)
      result
    end

    define_command(:eval_buffer) do
      buffer = Buffer.current
      result = eval(buffer.to_s, TOPLEVEL_BINDING,
                    buffer.file_name || buffer.name, 1)
      message(result.inspect)
      result
    end

    define_command(:eval_region) do
      buffer = Buffer.current
      b, e = buffer.point, buffer.mark
      if e < b
        b, e = e, b
      end
      result = eval(buffer.substring(b, e), TOPLEVEL_BINDING,
                    "(eval_region)", 1)
      message(result.inspect)
      result
    end

    define_command(:exit_recursive_edit) do
      if Controller.current.recursive_edit_level == 0
        raise EditorError, "No recursive edit is in progress"
      end
      throw RECURSIVE_EDIT_TAG, false
    end

    define_command(:abort_recursive_edit) do
      if Controller.current.recursive_edit_level == 0
        raise EditorError, "No recursive edit is in progress"
      end
      throw RECURSIVE_EDIT_TAG, true
    end

    define_command(:top_level) do
      throw TOP_LEVEL_TAG
    end

    define_command(:keyboard_quit) do
      raise Quit
    end

    def update_completions(xs)
      if xs.size > 1
        if COMPLETION[:original_buffer].nil?
          COMPLETION[:completions_window] = Window.windows[-2]
          COMPLETION[:original_buffer] =
            COMPLETION[:completions_window].buffer
        end
        completions = Buffer.find_or_new("*Completions*", undo_limit: 0)
        if !completions.mode.is_a?(CompletionListMode)
          completions.apply_mode(CompletionListMode)
        end
        completions.read_only = false
        begin
          completions.clear
          xs.each do |x|
            completions.insert(x + "\n")
          end
          COMPLETION[:completions_window].buffer = completions
        ensure
          completions.read_only = true
        end
      else
        if COMPLETION[:original_buffer]
          COMPLETION[:completions_window].buffer =
            COMPLETION[:original_buffer]
        end
      end
    end
    private :update_completions

    def complete_minibuffer_with_string(s)
      minibuffer = Buffer.minibuffer
      if s.start_with?(minibuffer.to_s)
        minibuffer.insert(s[minibuffer.to_s.size..-1])
      else
        minibuffer.delete_region(minibuffer.point_min,
                                 minibuffer.point_max)
        minibuffer.insert(s)
      end
    end
    private :complete_minibuffer_with_string

    define_command(:complete_minibuffer) do
      minibuffer = Buffer.minibuffer
      completion_proc = minibuffer[:completion_proc]
      if completion_proc
        xs = completion_proc.call(minibuffer.to_s)
        update_completions(xs)
        if xs.empty?
          message("No match", sit_for: 1)
          return
        end
        y, *ys = xs
        s = y.size.downto(1).lazy.map { |i|
          y[0, i]
        }.find { |i|
          ys.all? { |j| j.start_with?(i) }
        }
        if s
          complete_minibuffer_with_string(s)
        end
      end
    end

    UNIVERSAL_ARGUMENT_MAP = Keymap.new
    (?0..?9).each do |c|
      UNIVERSAL_ARGUMENT_MAP.define_key(c, :digit_argument)
      GLOBAL_MAP.define_key("\e#{c}", :digit_argument)
    end
    UNIVERSAL_ARGUMENT_MAP.define_key(?-, :negative_argument)
    UNIVERSAL_ARGUMENT_MAP.define_key(?\C-u, :universal_argument_more)

    def universal_argument_mode
      set_transient_map(UNIVERSAL_ARGUMENT_MAP)
    end

    define_command(:universal_argument) do
      Controller.current.prefix_arg = [4]
      universal_argument_mode
    end

    def current_prefix_arg
      Controller.current.current_prefix_arg
    end

    def number_prefix_arg
      arg = current_prefix_arg
      case arg
      when Integer
        arg
      when Array
        arg.first
      when :-
        -1
      else
        1
      end
    end

    define_command(:digit_argument) do
      |arg = current_prefix_arg|
      n = Controller.current.last_key.to_i
      Controller.current.prefix_arg =
        case arg
        when Integer
          arg * 10 + (arg < 0 ? -n : n)
        when :-
          -n
        else
          n
        end
      universal_argument_mode
    end

    define_command(:negative_argument) do
      |arg = current_prefix_arg|
      Controller.current.prefix_arg =
        case arg
        when Integer
          -arg
        when :-
          nil
        else
          :-
        end
      universal_argument_mode
    end

    define_command(:universal_argument_more) do
      |arg = current_prefix_arg|
      Controller.current.prefix_arg =
        case arg
        when Array
          [4 * arg.first]
        when :-
          [-4]
        else
          nil
        end
      if Controller.current.prefix_arg
        universal_argument_mode
      end
    end

    define_command(:recursive_edit) do
      Controller.current.recursive_edit
    end

    define_command(:shell_execute) do
      |cmd = read_from_minibuffer("Shell execute: "),
       buffer_name = "*Shell output*"|
      buffer = Buffer.find_or_new(buffer_name)
      switch_to_buffer(buffer)
      buffer.read_only = false
      buffer.clear
      Window.redisplay
      signals = [:INT, :TERM, :KILL]
      begin
        if /mswin32|mingw32/ =~ RUBY_PLATFORM
          opts = {}
        else
          opts = {pgroup: true}
        end
        Open3.popen2e(cmd, opts) do |input, output, wait_thread|
          input.close
          loop do
            status = output.wait_readable(0.5)
            if status == false
              break # EOF
            end
            if status
              begin
                s = output.read_nonblock(1024).force_encoding("utf-8").
                  scrub("\u{3013}").gsub(/\r\n/, "\n")
                buffer.insert(s)
                Window.redisplay
              rescue EOFError
                break
              rescue Errno::EAGAIN, Errno::EWOULDBLOCK
                next
              end
            end
            if received_keyboard_quit?
              if signals.empty?
                keyboard_quit
              else
                sig = signals.shift
                pid = wait_thread.pid
                pid = -pid if /mswin32|mingw32/ !~ RUBY_PLATFORM
                message("Send #{sig} to #{pid}")
                Process.kill(sig, pid)
              end
            end
          end
          status = wait_thread.value
          pid = status.pid
          if status.exited?
            code = status.exitstatus
            message("Process #{pid} exited with status code #{code}")
          elsif status.signaled?
            signame = Signal.signame(status.termsig)
            message("Process #{pid} was killed by #{signame}")
          else
            message("Process #{pid} exited")
          end
        end
      ensure
        buffer.read_only = true
      end
    end
  end
end
