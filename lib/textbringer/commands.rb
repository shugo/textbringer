# frozen_string_literal: true

require_relative "minibuffer"

module Textbringer
  module Commands
    include Minibuffer

    @@command_list = []

    def self.list
      @@command_list
    end

    def define_command(name, &block)
      define_method(name, &block)
      @@command_list << name if !@@command_list.include?(name)
    end
    module_function :define_command

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
      :beginning_of_line,
      :end_of_line,
      :beginning_of_buffer,
      :end_of_buffer,
      :set_mark,
      :exchange_point_and_mark,
      :copy_region,
      :kill_region,
      :yank,
      :newline,
      :delete_region,
      :undo,
      :redo,
      :transpose_chars
    ].each do |name|
      define_command(name) do
        Buffer.current.send(name)
      end
    end

    define_command(:goto_char) do
      |n = read_from_minibuffer("Go to char: ")|
      Buffer.current.goto_char(n.to_i)
    end

    define_command(:goto_line) do
      |n = read_from_minibuffer("Go to line: ")|
      Buffer.current.goto_line(n.to_i)
    end

    define_command(:self_insert) do
      Buffer.current.insert(Controller.current.last_key.chr(Encoding::UTF_8),
                            Controller.current.last_command == :self_insert)
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
        raise "Previous command was not a yank"
      end
      Buffer.current.yank_pop
      Controller.current.this_command = :yank
    end

    define_command(:re_search_forward) do
      |s = read_from_minibuffer("RE search: ", default: @last_search_re)|
      Buffer.current.re_search_forward(s)
      @last_search_re = s
    end
          
    define_command(:resize_window) do
      Window.resize
    end

    define_command(:scroll_up) do
      Window.current.scroll_up
    end

    define_command(:scroll_down) do
      Window.current.scroll_down
    end

    define_command(:exit_textbringer) do |status = 0|
      if Buffer.any? { |buffer| /\A\*/ !~ buffer.name && buffer.modified? }
        return unless yes_or_no?("Unsaved buffers exist; exit anyway?")
      end
      exit(status)
    end

    define_command(:suspend_textbringer) do
      Ncurses.endwin
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
      Buffer.current.save
      message("Wrote #{Buffer.current.file_name}")
    end

    define_command(:write_file) do
      |file_name = read_file_name("Write file: ")|
      Buffer.current.file_name = file_name
      if File.basename(file_name) != Buffer.current.name
        Buffer.current.name = File.basename(file_name)
      end
      Buffer.current.save
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
        raise "Undefined command: #{cmd}"
      end
      begin
        send(cmd)
      ensure
        Controller.current.this_command ||= cmd
      end
    end

    define_command(:eval_expression) do
      |s = read_from_minibuffer("Eval: ")|
      message(eval(s, TOPLEVEL_BINDING).inspect)
    end

    define_command(:eval_buffer) do
      message(eval(Buffer.current.to_s, TOPLEVEL_BINDING).inspect)
    end

    define_command(:exit_recursive_edit) do
      if @recursive_edit_level == 0
        raise "No recursive edit is in progress"
      end
      throw RECURSIVE_EDIT_TAG, false
    end

    define_command(:abort_recursive_edit) do
      if @recursive_edit_level == 0
        raise "No recursive edit is in progress"
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

    define_command(:keyboard_quit) do
      raise Quit
    end

    define_command(:recursive_edit) do
      Controller.current.recursive_edit
    end
  end

  class Quit < StandardError
    def initialize
      super("Quit")
    end
  end
end
