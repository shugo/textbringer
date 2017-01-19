# frozen_string_literal: true

module Textbringer
  class Mode
    extend Commands
    include Commands

    class << self
      attr_accessor :mode_name
    end

    def self.define_generic_command(name)
      define_command(name) do |*args|
        Buffer.current.mode.send(name, *args)
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
      define_command(command) do
        Buffer.current.mode = child.new(Buffer.current)
        run_hooks(hook)
      end
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
