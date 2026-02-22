module Textbringer
  module Commands
    define_command(:version) do
      message("Textbringer #{Textbringer::VERSION} "\
              "(ruby #{RUBY_VERSION} [#{RUBY_PLATFORM}])")
    end

    define_command(:exit_textbringer) do |status = 0|
      unsaved_buffers = Buffer.filter { |buffer|
        /\A\*/ !~ buffer.name && buffer.modified?
      }
      if !unsaved_buffers.empty?
        list_buffers(unsaved_buffers)
        Window.redisplay
        return unless yes_or_no?("Unsaved buffers exist; exit anyway?")
      end
      exit(status)
    end

    define_command(:suspend_textbringer) do
      Curses.close_screen
      Process.kill(:STOP, 0)
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
      |s = read_expression("Eval: ")|
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
      buffer.deactivate_mark
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
        if COMPLETION[:completions_window].nil?
          Window.list.last.split
          COMPLETION[:completions_window] = Window.list.last
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
          completions.beginning_of_buffer
          COMPLETION[:completions_window].buffer = completions
        ensure
          completions.read_only = true
        end
      else
        delete_completions_window
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
      ignore_case = minibuffer[:completion_ignore_case]
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
          i = i.downcase if ignore_case
          ys.all? { |j|
            j = j.downcase if ignore_case
            j.start_with?(i)
          }
        }
        if s
          complete_minibuffer_with_string(s)
        end
      end
    end

    define_keymap :UNIVERSAL_ARGUMENT_MAP
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

    def prefix_numeric_value(arg)
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

    def number_prefix_arg
      prefix_numeric_value(current_prefix_arg)
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

    def goto_global_mark
      global_mark_ring = Buffer.global_mark_ring
      mark = yield(global_mark_ring)
      if mark.buffer&.current? && Buffer.current.point_at_mark?(mark)
        mark = yield(global_mark_ring)
      end
      if mark.detached?
        unless mark.file_name
          raise EditorError, "The buffer has gone"
        end
        find_file(mark.file_name)
        goto_char(mark.location)
      else
        switch_to_buffer(mark.buffer)
        mark.buffer.point_to_mark(mark)
      end
    end
    private :goto_global_mark

    define_command(:next_global_mark) do
      if Buffer.global_mark_ring.empty?
        raise EditorError, "Global mark ring is empty"
      end
      if Buffer.current.push_global_mark
        Buffer.global_mark_ring.pop
      end
      goto_global_mark do |mark_ring|
        mark_ring.pop
      end
    end

    define_command(:previous_global_mark) do
      if Buffer.global_mark_ring.empty?
        raise EditorError, "Global mark ring is empty"
      end
      Buffer.current.push_global_mark
      goto_global_mark do |mark_ring|
        mark_ring.rotate(-1)
      end
    end

    define_command(:shell_execute) do
      |cmd = read_from_minibuffer("Shell execute: "),
       buffer_name: "*Shell output*",
       mode: FundamentalMode|
      buffer = Buffer.find_or_new(buffer_name)
      switch_to_buffer(buffer)
      buffer.apply_mode(mode)
      buffer.read_only = false
      buffer.clear
      Window.redisplay
      signals = [:INT, :TERM, :KILL]
      begin
        opts = /mswin|mingw/ =~ RUBY_PLATFORM ? {} : {pgroup: true}
        if CONFIG[:shell_file_name]
          cmd = [CONFIG[:shell_file_name], CONFIG[:shell_command_switch], cmd]
        end
        Open3.popen3(*cmd, opts) do |input, output, error, wait_thread|
          input.close
          catch(:finish) do
            loop do
              rs, = IO.select([output, error], nil, nil, 0.5)
              Window.redisplay
              rs&.each do |r|
                begin
                  s = r.read_nonblock(1024).force_encoding("utf-8").
                    scrub("\u{3013}").gsub(/\r\n/, "\n")
                  buffer.insert(s)
                  Window.redisplay
                rescue EOFError
                  throw(:finish) if output.eof? && error.eof?
                rescue Errno::EAGAIN, Errno::EWOULDBLOCK
                  Window.redisplay
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
          end
          status = wait_thread.value
          pid = status.pid
          if status.exited?
            code = status.exitstatus
            message("Process #{pid} exited with status code #{code}")
          elsif status.signaled?
            signame = Signal.signame(status.termsig)
            message("Process #{pid} was killed by #{signame}")
          end
        end
      ensure
        buffer.read_only = true
      end
    end

    define_command(:grep) do
      |cmd = read_from_minibuffer("Grep: ",
                                  initial_value: CONFIG[:grep_command] + " ")|
      shell_execute(cmd, buffer_name: "*grep*", mode: BacktraceMode)
    end

    define_command(:jit_pause) do
      RubyVM::MJIT.pause
    end

    define_command(:jit_resume) do
      RubyVM::MJIT.resume
    end

    define_command(:what_cursor_position,
                   doc: "Print info on cursor position.") do
      |arg = current_prefix_arg|

      buffer = Buffer.current
      c = buffer.char_after
      if c
        char = format("Char: %s (U+%04X) ",
                      /[\0-\x20\x7f]/.match?(c) ? Keymap.key_name(c) : c,
                      c.ord)
      else
        char = ""
      end
      if buffer.bytesize == 0
        percent = "EOB"
      else
        percent = (100.0 * buffer.point / buffer.bytesize).to_i
      end
      column = buffer.current_column
      message("#{char}point=#{buffer.point} of #{buffer.bytesize} (#{percent}%) column=#{column}")
      if arg && c
        describe_char
      end
    end
  end
end
