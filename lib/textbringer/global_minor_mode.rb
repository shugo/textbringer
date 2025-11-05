module Textbringer
  # Base class for global minor modes that affect all buffers.
  # Unlike buffer-local MinorMode, global minor modes have a single on/off state.
  class GlobalMinorMode
    extend Commands
    include Commands

    class << self
      attr_accessor :mode_name
      attr_accessor :command_name
      attr_reader :enabled

      def enabled=(val)
        @enabled = val
      end
    end

    def self.inherited(child)
      # Initialize enabled to false immediately
      child.instance_variable_set(:@enabled, false)

      # Only allow named classes to inherit GlobalMinorMode
      if child.name.nil? || child.name.empty?
        raise ArgumentError, "GlobalMinorMode subclasses must be named classes (anonymous classes are not supported)"
      end

      base_name = child.name.slice(/[^:]*\z/)
      child.mode_name = base_name.sub(/Mode\z/, "")
      command_name = base_name.sub(/\A[A-Z]/) { |s| s.downcase }.
        gsub(/(?<=[a-z])([A-Z])/) {
          "_" + $1.downcase
        }
      command = command_name.intern
      child.command_name = command

      # Define the toggle command
      define_command(command) do
        if child.enabled
          child.disable
          child.enabled = false
        else
          child.enable
          child.enabled = true
        end
      end
    end

    def self.name
      mode_name
    end

    # Override these in subclasses
    def self.enable
      raise EditorError, "Subclass must implement enable"
    end

    def self.disable
      raise EditorError, "Subclass must implement disable"
    end
  end
end
