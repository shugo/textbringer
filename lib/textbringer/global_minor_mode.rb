module Textbringer
  # Base class for global minor modes that affect all buffers.
  # Unlike buffer-local MinorMode, global minor modes have a single on/off state.
  class GlobalMinorMode
    extend Commands
    include Commands

    class << self
      attr_accessor :mode_name
      attr_accessor :command_name

      def enabled=(val)
        @enabled = val
      end

      def enabled? = @enabled
    end

    def self.inherited(child)
      # Initialize enabled to false immediately
      child.instance_variable_set(:@enabled, false)

      class_name = child.name
      if class_name.nil? || class_name.empty?
        raise ArgumentError, "GlobalMinorMode subclasses must be named classes (anonymous classes are not supported)"
      end

      base_name = class_name.slice(/[^:]*\z/)
      child.mode_name = base_name.sub(/Mode\z/, "")
      command_name = base_name.sub(/\A[A-Z]/) { |s| s.downcase }.
        gsub(/(?<=[a-z])([A-Z])/) {
          "_" + $1.downcase
        }
      command = command_name.intern
      child.command_name = command

      # Define the toggle command
      define_command(command, doc: "Enable or disable #{command_name}.  " \
                     "Toggle the mode if arg is nil.  " \
                     "Enable the mode if arg is true.  " \
                     "Disable the mode if arg is false") do |arg = nil|
        enable =
          case arg
          when true, false
            return if child.enabled? == arg
            arg
          when nil
            !child.enabled?
          else
            raise ArgumentError, "wrong argument #{arg.inspect} (expected true, false, or nil)"
          end
        if enable
          child.enable
          child.enabled = true
        else
          child.disable
          child.enabled = false
        end
      end
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
