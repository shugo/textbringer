require "set"

module Textbringer
  # Transient Mark Mode is a buffer-local minor mode that highlights
  # the region between mark and point when the mark is active.
  class TransientMarkMode < MinorMode
    class << self
      attr_accessor :global_enabled
    end
    @global_enabled = false

    # Commands that should NOT deactivate the mark
    MARK_PRESERVING_COMMANDS = [
      :set_mark_command,
      :exchange_point_and_mark,
      :transient_mark_mode,
      # Navigation commands that should preserve mark
      :beginning_of_line,
      :end_of_line,
      :next_line,
      :previous_line,
      :forward_char,
      :backward_char,
      :forward_word,
      :backward_word,
      :scroll_up_command,
      :scroll_down_command,
      :beginning_of_buffer,
      :end_of_buffer,
      # Search commands
      :isearch_forward,
      :isearch_backward,
      :isearch_repeat_forward,
      :isearch_repeat_backward,
      # Undo/redo
      :undo,
      :redo_command,
      # Other navigation
      :goto_line,
      :goto_char,
      :recenter,
      :move_to_beginning_of_line,
      :move_to_end_of_line
    ].to_set.freeze

    # Hook to deactivate mark before most commands
    PRE_COMMAND_HOOK = -> {
      buffer = Buffer.current
      controller = Controller.current

      return unless buffer.mark_active?

      # Check if this command preserves the mark
      command = controller.this_command
      unless MARK_PRESERVING_COMMANDS.include?(command)
        buffer.deactivate_mark
      end
    }

    # Hook to update visible mark after commands
    POST_COMMAND_HOOK = -> {
      buffer = Buffer.current

      # Update visible_mark to reflect mark_active state
      if buffer.mark_active? && buffer.mark
        buffer.set_visible_mark(buffer.mark.location)
      elsif !buffer.mark_active? && buffer.visible_mark
        buffer.delete_visible_mark
      end
    }

    define_command(:global_transient_mark_mode,
                   doc: "Toggle Transient Mark mode in all buffers.") do
      if TransientMarkMode.global_enabled
        TransientMarkMode.global_enabled = false
        Buffer.list.each do |buffer|
          if buffer.minor_mode_active?(TransientMarkMode)
            buffer.toggle_minor_mode(TransientMarkMode)
          end
        end
        message("Global Transient Mark mode disabled")
      else
        TransientMarkMode.global_enabled = true
        Buffer.list.each do |buffer|
          unless buffer.minor_mode_active?(TransientMarkMode)
            buffer.toggle_minor_mode(TransientMarkMode)
          end
        end
        message("Global Transient Mark mode enabled")
      end
    end

    def initialize(buffer)
      super(buffer)
    end

    def enable
      # Add hooks - use local: true so they only affect this buffer
      add_hook(:pre_command_hook, PRE_COMMAND_HOOK, local: true)
      add_hook(:post_command_hook, POST_COMMAND_HOOK, local: true)
    end

    def disable
      # Remove hooks
      remove_hook(:pre_command_hook, PRE_COMMAND_HOOK, local: true)
      remove_hook(:post_command_hook, POST_COMMAND_HOOK, local: true)

      # Deactivate mark
      @buffer.deactivate_mark
    end

    def name
      "Transient Mark"
    end
  end
end
