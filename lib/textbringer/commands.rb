# frozen_string_literal: true

require "open3"
require "io/wait"

module Textbringer
  module Commands
    include Utils

    @@command_list = []

    def self.list
      @@command_list
    end

    def define_command(name, &block)
      Commands.send(:define_method, name, &block)
      @@command_list << name if !@@command_list.include?(name)
    end
    module_function :define_command

    def undefine_command(name)
      if @@command_list.include?(name)
        Commands.send(:undef_method, name)
        @@command_list.delete(name)
      end
    end
    module_function :undefine_command

    define_command(:version) do
      message("Textbringer #{Textbringer::VERSION} "\
              "(ruby #{RUBY_VERSION} [#{RUBY_PLATFORM}])")
    end

    [
      :forward_char,
      :backward_char,
      :forward_word,
      :backward_word,
      :next_line,
      :previous_line,
      :delete_char,
      :backward_delete_char,
    ].each do |name|
      define_command(name) do |n = number_prefix_arg|
        Buffer.current.send(name, n)
      end
    end

    [
      :beginning_of_line,
      :end_of_line,
      :beginning_of_buffer,
      :end_of_buffer,
      :exchange_point_and_mark,
      :copy_region,
      :kill_region,
      :yank,
      :newline,
      :delete_region,
      :transpose_chars
    ].each do |name|
      define_command(name) do
        Buffer.current.send(name)
      end
    end

    define_command(:set_mark_command) do
      Buffer.current.set_mark
      message("Mark set")
    end

    define_command(:goto_char) do
      |n = read_from_minibuffer("Go to char: ")|
      Buffer.current.goto_char(n.to_i)
      Window.current.recenter_if_needed
    end

    define_command(:goto_line) do
      |n = read_from_minibuffer("Go to line: ")|
      Buffer.current.goto_line(n.to_i)
      Window.current.recenter_if_needed
    end

    define_command(:self_insert) do |n = number_prefix_arg|
      c = Controller.current.last_key
      merge_undo = Controller.current.last_command == :self_insert
      n.times do
        Buffer.current.insert(c, merge_undo)
      end
    end

    define_command(:quoted_insert) do |n = number_prefix_arg|
      c = Controller.current.read_char
      if !c.is_a?(String)
        raise "Invalid key"
      end
      n.times do
        Buffer.current.insert(c)
      end
    end

    define_command(:kill_line) do
      Buffer.current.kill_line(Controller.current.last_command == :kill_region)
      Controller.current.this_command = :kill_region
    end

    define_command(:kill_word) do
      Buffer.current.kill_word(Controller.current.last_command == :kill_region)
      Controller.current.this_command = :kill_region
    end

    define_command(:yank_pop) do
      if Controller.current.last_command != :yank
        raise EditorError, "Previous command was not a yank"
      end
      Buffer.current.yank_pop
      Controller.current.this_command = :yank
    end

    RE_SEARCH_STATUS = {
      last_regexp: nil
    }

    define_command(:re_search_forward) do
      |s = read_from_minibuffer("RE search: ",
                                default: RE_SEARCH_STATUS[:last_regexp])|
      RE_SEARCH_STATUS[:last_regexp] = s
      Buffer.current.re_search_forward(s)
    end

    define_command(:re_search_backward) do
      |s = read_from_minibuffer("RE search backward: ",
                                default: RE_SEARCH_STATUS[:last_regexp])|
      RE_SEARCH_STATUS[:last_regexp] = s
      Buffer.current.re_search_backward(s)
    end

    def match_beginning(n)
      Buffer.current.match_beginning(n)
    end

    def match_end(n)
      Buffer.current.match_end(n)
    end

    def match_string(n)
      Buffer.current.match_string(n)
    end

    def replace_match(s)
      Buffer.current.replace_match(s)
    end

    define_command(:query_replace_regexp) do
      |regexp = read_from_minibuffer("Query replace regexp: "),
       to_str = read_from_minibuffer("with: ")|
      n = 0
      begin
        loop do
          re_search_forward(regexp)
          Window.current.recenter_if_needed
          Buffer.current.set_visible_mark(match_beginning(0))
          begin
            Window.redisplay
            c = read_single_char("Replace?", [?y, ?n, ?!, ?q, ?.])
            case c
            when ?y
              replace_match(to_str)
              n += 1
            when ?n
              # do nothing
            when ?!
              replace_match(to_str)
              n += 1 + Buffer.current.replace_regexp_forward(regexp, to_str)
              Buffer.current.merge_undo(2)
              break
            when ?q
              break
            when ?.
              replace_match(to_str)
              n += 1
              break
            end
          ensure
            Buffer.current.delete_visible_mark
          end
        end
      rescue SearchError
      end
      if n == 1
        message("Replaced 1 occurrence")
      else
        message("Replaced #{n} occurrences")
      end
    end

    define_command(:undo) do
      Buffer.current.undo
      message("Undo!")
    end

    define_command(:redo) do
      Buffer.current.redo
      message("Redo!")
    end
          
    define_command(:resize_window) do
      Window.resize
    end

    define_command(:recenter) do
      Window.current.recenter
      Window.redraw
    end

    define_command(:scroll_up) do
      Window.current.scroll_up
    end

    define_command(:scroll_down) do
      Window.current.scroll_down
    end

    define_command(:delete_window) do
      Window.delete_window
    end

    define_command(:delete_other_windows) do
      Window.delete_other_windows
    end

    define_command(:split_window) do
      Window.current.split
    end

    define_command(:other_window) do
      Window.other_window
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

    define_command(:pwd) do
      message(Dir.pwd)
    end

    define_command(:chdir) do
      |dir_name = read_file_name("Change directory: ")|
      Dir.chdir(dir_name)
    end

    define_command(:find_file) do
      |file_name = read_file_name("Find file: ")|
      buffer = Buffer.find_file(file_name)
      if buffer.new_file?
        message("New file")
      end
      switch_to_buffer(buffer)
      shebang = buffer.save_excursion {
        buffer.beginning_of_buffer
        buffer.looking_at?(/#!.*$/) ? buffer.match_string(0) : nil
      }
      mode = Mode.list.find { |m|
        (m.file_name_pattern &&
         m.file_name_pattern =~ File.basename(buffer.file_name)) ||
          (m.interpreter_name_pattern &&
           m.interpreter_name_pattern =~ shebang)
      } || FundamentalMode
      send(mode.command_name)
    end

    define_command(:switch_to_buffer) do
      |buffer_name = read_buffer("Switch to buffer: ")|
      if buffer_name.is_a?(Buffer)
        buffer = buffer_name
      else
        buffer = Buffer[buffer_name]
      end
      if buffer
        Window.current.buffer = Buffer.current = buffer
      else
        message("No such buffer: #{buffer_name}")
      end
    end

    define_command(:save_buffer) do
      if Buffer.current.file_name.nil?
        Buffer.current.file_name = read_file_name("File to save in: ")
        next if Buffer.current.file_name.nil?
      end
      if Buffer.current.file_modified?
        unless yes_or_no?("File changed on disk.  Save anyway?")
          message("Cancelled")
          next
        end
      end
      Buffer.current.save
      message("Wrote #{Buffer.current.file_name}")
    end

    define_command(:write_file) do
      |file_name = read_file_name("Write file: ")|
      if File.directory?(file_name)
        file_name = File.expand_path(Buffer.current.name, file_name)
      end
      if File.exist?(file_name)
        unless y_or_n?("File `#{file_name}' exists; overwrite?")
          message("Cancelled")
          next
        end
      end
      Buffer.current.save(file_name)
      message("Wrote #{Buffer.current.file_name}")
    end

    define_command(:kill_buffer) do
      |name = read_buffer("Kill buffer: ", default: Buffer.current.name)|
      if name.is_a?(Buffer)
        buffer = name
      else
        buffer = Buffer[name]
      end
      if buffer.modified?
        next unless yes_or_no?("The last change is not saved; kill anyway?")
        message("Arioch! Arioch! Blood and souls for my Lord Arioch!")
      end
      buffer.kill
      if Buffer.count == 0
        buffer = Buffer.new_buffer("*scratch*")
        switch_to_buffer(buffer)
      elsif Buffer.current.nil?
        switch_to_buffer(Buffer.last)
      end
    end

    define_command(:set_buffer_file_encoding) do
      |enc = read_from_minibuffer("File encoding: ",
                                  default: Buffer.current.file_encoding.name)|
      Buffer.current.file_encoding = Encoding.find(enc)
    end

    define_command(:set_buffer_file_format) do
      |format = read_from_minibuffer("File format: ",
                                     default: Buffer.current.file_format.to_s)|
      Buffer.current.file_format = format
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
      message(eval(s, TOPLEVEL_BINDING, "(eval_expression)", 1).inspect)
    end

    define_command(:eval_buffer) do
      buffer = Buffer.current
      result = eval(buffer.to_s, TOPLEVEL_BINDING,
                    buffer.file_name || buffer.name, 1)
      message(result.inspect)
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

    define_command(:complete_minibuffer) do
      minibuffer = Buffer.minibuffer
      completion_proc = minibuffer[:completion_proc]
      if completion_proc
        s = completion_proc.call(minibuffer.to_s)
        if s
          minibuffer.delete_region(minibuffer.point_min,
                                   minibuffer.point_max)
          minibuffer.insert(s)
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
      n = last_key.to_i
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

    define_command(:keyboard_quit) do
      raise Quit
    end

    define_command(:recursive_edit) do
      Controller.current.recursive_edit
    end

    ISEARCH_MODE_MAP = Keymap.new
    (?\x20..?\x7e).each do |c|
      ISEARCH_MODE_MAP.define_key(c, :isearch_printing_char)
    end
    ISEARCH_MODE_MAP.define_key(?\t, :isearch_printing_char)
    ISEARCH_MODE_MAP.handle_undefined_key do |key|
      if key.is_a?(String) && /[\0-\x7f]/ !~ key 
        :isearch_printing_char
      else
        nil
      end
    end
    ISEARCH_MODE_MAP.define_key(:backspace, :isearch_delete_char)
    ISEARCH_MODE_MAP.define_key(?\C-h, :isearch_delete_char)
    ISEARCH_MODE_MAP.define_key(?\C-s, :isearch_repeat_forward)
    ISEARCH_MODE_MAP.define_key(?\C-r, :isearch_repeat_backward)
    ISEARCH_MODE_MAP.define_key(?\n, :isearch_exit)
    ISEARCH_MODE_MAP.define_key(?\C-g, :isearch_abort)
    
    ISEARCH_STATUS = {
      forward: true,
      string: "",
      last_string: "",
      start: 0,
      last_pos: 0,
      recursive_edit: false
    }

    define_command(:isearch_forward) do |**options|
      isearch_mode(true, **options)
    end

    define_command(:isearch_backward) do |**options|
      isearch_mode(false, **options)
    end

    def isearch_mode(forward, recursive_edit: false)
      ISEARCH_STATUS[:forward] = forward
      ISEARCH_STATUS[:string] = String.new
      ISEARCH_STATUS[:recursive_edit] = recursive_edit
      Controller.current.overriding_map = ISEARCH_MODE_MAP
      run_hooks(:isearch_mode_hook)
      add_hook(:pre_command_hook, :isearch_pre_command_hook)
      ISEARCH_STATUS[:start] = ISEARCH_STATUS[:last_pos] = Buffer.current.point
      if Buffer.current != Buffer.minibuffer
        message(isearch_prompt, log: false)
      end
      if recursive_edit
        recursive_edit()
      end
    end

    def isearch_prompt
      if ISEARCH_STATUS[:forward]
        "I-search: "
      else
        "I-search backward: "
      end
    end

    def isearch_pre_command_hook
      if /\Aisearch_/ !~ Controller.current.this_command
        isearch_done
      end
    end

    def isearch_done
      Buffer.current.delete_visible_mark
      Controller.current.overriding_map = nil
      remove_hook(:pre_command_hook, :isearch_pre_command_hook)
      ISEARCH_STATUS[:last_string] = ISEARCH_STATUS[:string]
      if ISEARCH_STATUS[:recursive_edit]
        exit_recursive_edit
      end
    end

    define_command(:isearch_exit) do
      isearch_done
    end

    define_command(:isearch_abort) do
      goto_char(Buffer.current[:isearch_start])
      isearch_done
      raise Quit
    end

    define_command(:isearch_printing_char) do
      c = Controller.current.last_key
      ISEARCH_STATUS[:string].concat(c)
      isearch_search
    end

    define_command(:isearch_delete_char) do
      ISEARCH_STATUS[:string].chop!
      isearch_search
    end

    def isearch_search
      forward = ISEARCH_STATUS[:forward]
      options = if /\A[A-Z]/ =~ ISEARCH_STATUS[:string]
                  nil
                else
                  Regexp::IGNORECASE
                end
      re = Regexp.new(Regexp.quote(ISEARCH_STATUS[:string]), options)
      last_pos = ISEARCH_STATUS[:last_pos]
      offset = forward ? last_pos : last_pos - ISEARCH_STATUS[:string].bytesize
      if Buffer.current.byteindex(forward, re, offset)
        if Buffer.current != Buffer.minibuffer
          message(isearch_prompt + ISEARCH_STATUS[:string], log: false)
        end
        Buffer.current.set_visible_mark(forward ? match_beginning(0) :
                                        match_end(0))
        goto_char(forward ? match_end(0) : match_beginning(0))
      else
        if Buffer.current != Buffer.minibuffer
          message("Falling " + isearch_prompt + ISEARCH_STATUS[:string],
                  log: false)
        end
      end
    end

    def isearch_repeat_forward
      isearch_repeat(true)
    end

    def isearch_repeat_backward
      isearch_repeat(false)
    end

    def isearch_repeat(forward)
      ISEARCH_STATUS[:forward] = forward
      ISEARCH_STATUS[:last_pos] = Buffer.current.point
      if ISEARCH_STATUS[:string].empty?
        ISEARCH_STATUS[:string] = ISEARCH_STATUS[:last_string]
      end
      isearch_search
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
                message("Send #{sig} to #{wait_thread.pid}")
                Process.kill(sig, -wait_thread.pid)
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

  class Quit < StandardError
    def initialize
      super("Quit")
    end
  end
end
