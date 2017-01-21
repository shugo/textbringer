# frozen_string_literal: true

module Textbringer
  class Mode
    extend Commands
    include Commands
    
    @@mode_list = []
    
    def self.list
      @@mode_list
    end

    class << self
      attr_accessor :mode_name
      attr_accessor :command_name
      attr_accessor :hook_name
      attr_accessor :file_name_pattern
    end

    def self.define_generic_command(name)
      command_name = (name.to_s + "_command").intern
      define_command(command_name) do |*args|
        begin
          Buffer.current.mode.send(name, *args)
        rescue NoMethodError => e
          if e.receiver == Buffer.current.mode && e.name == name
            raise EditorError,
              "#{command_name} is not supported in the current mode"
          else
            raise
          end
        end
      end
    end

    def self.inherited(child)
      base_name = child.name.slice(/[^:]*\z/)
      child.mode_name = base_name.sub(/Mode\z/, "")
      command_name = base_name.sub(/\A[A-Z]/) { |s| s.downcase }.
        gsub(/(?<=[a-z])([A-Z])/) {
          "_" + $1.downcase
        }
      command = command_name.intern
      hook = (command_name + "_hook").intern
      child.command_name = command
      child.hook_name = hook
      define_command(command) do
        Buffer.current.apply_mode(child)
      end
      @@mode_list.push(child)
    end

    attr_reader :buffer

    def initialize(buffer)
      @buffer = buffer
    end

    def name
      self.class.mode_name
    end
  end
end
