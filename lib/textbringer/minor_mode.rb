module Textbringer
  class MinorMode
    extend Commands
    include Commands

    class << self
      attr_accessor :mode_name
      attr_accessor :command_name
    end

    def self.inherited(child)
      base_name = child.name.slice(/[^:]*\z/)
      child.mode_name = base_name.sub(/Mode\z/, "")
      command_name = base_name.sub(/\A[A-Z]/) { |s| s.downcase }.
        gsub(/(?<=[a-z])([A-Z])/) {
          "_" + $1.downcase
        }
      command = command_name.intern
      child.command_name = command
      define_command(command) do
        Buffer.current.toggle_minor_mode(child)
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
