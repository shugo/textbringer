# frozen_string_literal: true

module Textbringer
  module Commands
    @list = []

    def initialize
      @this_command = nil
      @last_command = nil
    end

    def self.list
      @list
    end

    def self.define_command(name, &block)
      define_method(name) do
        @this_command = nil
        begin
          instance_eval(&block)
        ensure
          @last_command = @this_command || name
        end
      end
      @list << name if !@list.include?(name)
    end

    [
      :forward_char,
      :backward_char,
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
      :undo
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

    define_command(:scroll_up) do
      @current_window.scroll_up
    end

    define_command(:scroll_down) do
      @current_window.scroll_down
    end

    define_command(:save_buffer) do
      if @current_buffer.filename.nil?
        @current_buffer.filename = read_from_minibuffer("Filename: ")
        next if @current_buffer.filename.nil?
      end
      @current_buffer.save
      message("Wrote #{@current_buffer.filename}")
    end

    define_command(:execute_command) do
      cmd = read_from_minibuffer("M-x ")&.strip&.intern
      next if cmd.nil?
      unless Commands.list.include?(cmd)
        raise "undefined command: #{cmd}"
      end
      begin
        send(cmd)
      ensure
        @this_command = @last_command
      end
    end

    define_command(:eval_expression) do
      s = read_from_minibuffer("Eval: ")
      next if s.nil?
      begin
        message(eval(s).inspect)
      rescue Exception => e
        message("#{e.class}: #{e}")
      end
    end
  end
end
