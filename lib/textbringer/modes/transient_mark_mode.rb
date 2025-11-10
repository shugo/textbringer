require "set"

module Textbringer
  # Transient Mark Mode is a global minor mode that highlights
  # the region between mark and point when the mark is active.
  class TransientMarkMode < GlobalMinorMode
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
      :isearch_printing_char,
      :isearch_delete_char,
      :isearch_yank_word_or_char,
      :isearch_exit,
      :isearch_quoted_insert,
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

      # Skip if in isearch or ispell mode (they manage their own highlighting)
      controller = Controller.current
      if controller.overriding_map
        return if Commands.const_defined?(:ISEARCH_MODE_MAP) &&
                  controller.overriding_map == Commands::ISEARCH_MODE_MAP
        return if Commands.const_defined?(:ISPELL_MODE_MAP) &&
                  controller.overriding_map == Commands::ISPELL_MODE_MAP
      end

      # Update visible_mark to reflect mark_active state
      if buffer.mark_active?
        begin
          mark = buffer.mark
          buffer.set_visible_mark(mark.location) if mark
        rescue EditorError
          # Mark is not set, do nothing
        end
      elsif !buffer.mark_active? && buffer.visible_mark
        buffer.delete_visible_mark
      end
    }

    def self.enable
      # Add global hooks (not buffer-local)
      add_hook(:pre_command_hook, PRE_COMMAND_HOOK, local: false)
      add_hook(:post_command_hook, POST_COMMAND_HOOK, local: false)
      message("Transient Mark mode enabled")
    end

    def self.disable
      # Remove global hooks
      remove_hook(:pre_command_hook, PRE_COMMAND_HOOK, local: false)
      remove_hook(:post_command_hook, POST_COMMAND_HOOK, local: false)

      # Deactivate mark in all buffers
      Buffer.list.each do |buffer|
        buffer.deactivate_mark
      end
      message("Transient Mark mode disabled")
    end
  end
end
