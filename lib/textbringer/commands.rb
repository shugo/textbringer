# frozen_string_literal: true

module Textbringer
  module Commands
    @list = []

    def initialize(*args)
      super
      @this_command = nil
      @last_command = nil
    end

    def self.list
      @list
    end

    def self.define_command(name, &block)
      define_method(name, &block)
      @list << name if !@list.include?(name)
    end

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
        @current_buffer.send(name)
      end
    end

    define_command(:self_insert) do
      @current_buffer.insert(last_key.chr, @last_command == :self_insert)
    end

    define_command(:kill_line) do
      @current_buffer.kill_line(@last_command == :kill_region)
      @this_command = :kill_region
    end

    define_command(:kill_word) do
      @current_buffer.kill_word(@last_command == :kill_region)
      @this_command = :kill_region
    end

    define_command(:yank_pop) do
      if @last_command != :yank
        raise "Previous command was not a yank"
      end
      @current_buffer.yank_pop
      @this_command = :yank
    end

    define_command(:re_search_forward) do
      |s = read_from_minibuffer("RE search: ")|
      @current_buffer.re_search_forward(s)
    end
          
    define_command(:resize_window) do
      @window.resize(Window.lines - 1, Window.columns)
      @echo_area.move(Window.lines - 1, 0)
      @echo_area.resize(1, Window.columns)
    end

    define_command(:scroll_up) do
      @current_window.scroll_up
    end

    define_command(:scroll_down) do
      @current_window.scroll_down
    end

    define_command(:exit_textbringer) do |status = 0|
      if @buffers.any?(&:modified?)
        return unless yes_or_no?("Unsaved buffers exist; exit anyway?")
      end
      exit(status)
    end

    define_command(:suspend_textbringer) do
      Ncurses.endwin
      Process.kill(:STOP, $$)
    end

    def new_buffer_name(file_name)
      name = File.basename(file_name)
      if @buffers.find { |buffer| buffer.name == name }
        name = (2..Float::INFINITY).lazy.map { |i|
          "#{name}<#{i}>"
        }.find { |i|
          @buffers.all? { |buffer| buffer.name != i }
        }
      end
      name
    end

    define_command(:find_file) do
      |file_name = read_file_name("Find file: ")|
      buffer = @buffers.find { |buffer| buffer.file_name == file_name }
      if buffer.nil?
        begin
          buffer = Buffer.open(file_name, name: new_buffer_name(file_name))
        rescue Errno::ENOENT
          buffer = Buffer.new(file_name: file_name,
                              name: new_buffer_name(file_name))
          message("New file")
        end
        @buffers.push(buffer)
      end
      switch_to_buffer(buffer)
    end

    define_command(:switch_to_buffer) do
      |buffer_name = read_buffer("Switch to buffer: ")|
      if buffer_name.is_a?(Buffer)
        buffer = buffer_name
      else
        buffer = @buffers.find { |i| i.name == buffer_name }
      end
      if buffer
        @buffers.delete(buffer)
        @buffers.push(buffer)
        @current_window.buffer = @current_buffer = buffer
      else
        message("No such buffer: #{buffer_name}")
      end
    end

    define_command(:save_buffer) do
      if @current_buffer.file_name.nil?
        @current_buffer.file_name = read_file_name("File to save in: ")
        next if @current_buffer.file_name.nil?
      end
      @current_buffer.save
      message("Wrote #{@current_buffer.file_name}")
    end

    define_command(:write_file) do
      |file_name = read_file_name("Write file: ")|
      @current_buffer.file_name = file_name
      if File.basename(file_name) != @current_buffer.name
        @current_buffer.name = new_buffer_name(file_name)
      end
      @current_buffer.save
      message("Wrote #{@current_buffer.file_name}")
    end

    define_command(:kill_buffer) do
      |name = read_buffer("Kill buffer: ", default: @current_buffer.name)|
      if name.is_a?(Buffer)
        buffer = name
      else
        buffer = @buffers.find { |i| i.name == name }
      end
      if buffer.modified?
        next unless yes_or_no?("The last change is not saved; kill anyway?")
      end
      @buffers.delete(buffer)
      if @buffers.empty?
        @buffers.push(Buffer.new(name: "Untitled"))
      end
      switch_to_buffer(@buffers.last)
    end

    define_command(:execute_command) do
      |cmd = read_command_name("M-x ").strip.intern|
      unless Commands.list.include?(cmd)
        raise "Undefined command: #{cmd}"
      end
      begin
        send(cmd)
      ensure
        @this_command ||= cmd
      end
    end

    define_command(:eval_expression) do
      |s = read_from_minibuffer("Eval: ")|
      begin
        message(eval(s).inspect)
      rescue Exception => e
        message("#{e.class}: #{e}")
      end
    end

    define_command(:eval_buffer) do
      begin
        message(eval(@current_buffer.to_s, TOPLEVEL_BINDING).inspect)
      rescue Exception => e
        message("#{e.class}: #{e}")
      end
    end

    define_command(:exit_minibuffer) do
      throw :minibuffer_exit
    end

    define_command(:complete_minibuffer) do
      if @minibuffer_completion_proc
        s = @minibuffer_completion_proc.call(@minibuffer.to_s)
        if s
          @minibuffer.delete_region(@minibuffer.point_min,
                                    @minibuffer.point_max)
          @minibuffer.insert(s)
        end
      end
    end

    define_command(:keyboard_quit) do
      raise KeyboardQuit, "Quit"
    end
  end

  class KeyboardQuit < StandardError
  end
end
