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
      :save,
      :delete_region
    ].each do |name|
      define_command(name) do
        @current_buffer.send(name)
      end
    end

    define_command(:self_insert) do
      @current_buffer.insert(last_key.chr)
    end

    define_command(:kill_line) do
      @current_buffer.kill_line(@last_command == :kill_region)
      @this_command = :kill_region
    end

    define_command(:execute_command) do
      cmd = read_from_minibuffer("M-x ")&.strip&.intern
      return if cmd.nil?
      unless Commands.list.include?(cmd)
        message("undefined command: #{cmd}")
        next
      end
      begin
        send(cmd)
      ensure
        @this_command = @last_command
      end
    end

    define_command(:eval_expression) do
      s = read_from_minibuffer("Eval: ")
      return if s.nil?
      begin
        message(eval(s).inspect)
      rescue Exception => e
        message("#{e.class}: #{e}")
      end
    end
  end
end
