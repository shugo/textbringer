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

      # Extract name from inspect string as fallback when .name is nil
      class_name = child.name || child.inspect
      return if class_name.nil? || class_name.empty?

      base_name = class_name.slice(/[^:]*\z/)
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
      raise NotImplementedError, "Subclass must implement enable"
    end

    def self.disable
      raise NotImplementedError, "Subclass must implement disable"
    end
  end
end
