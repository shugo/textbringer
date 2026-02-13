# frozen_string_literal: true

module Textbringer
  module Commands
    define_keymap :COMPLETION_POPUP_MAP

    # Navigation keys
    COMPLETION_POPUP_MAP.define_key("\C-n", :completion_popup_next)
    COMPLETION_POPUP_MAP.define_key(:down, :completion_popup_next)
    COMPLETION_POPUP_MAP.define_key("\C-p", :completion_popup_previous)
    COMPLETION_POPUP_MAP.define_key(:up, :completion_popup_previous)

    # Accept keys
    COMPLETION_POPUP_MAP.define_key("\C-m", :completion_popup_accept)  # RET
    COMPLETION_POPUP_MAP.define_key("\t", :completion_popup_accept)    # Tab

    # Cancel keys
    COMPLETION_POPUP_MAP.define_key("\C-g", :completion_popup_cancel)

    # Handle undefined keys - close popup and forward the key
    COMPLETION_POPUP_MAP.handle_undefined_key do |key|
      :completion_popup_self_insert_and_close
    end

    COMPLETION_POPUP_STATUS = {
      active: false,
      start_point: nil
    }

    def self.completion_popup_mode_active?
      COMPLETION_POPUP_STATUS[:active]
    end

    define_command(:completion_popup_next,
                   doc: "Select next completion candidate.") do
      CompletionPopup.instance.select_next
    end

    define_command(:completion_popup_previous,
                   doc: "Select previous completion candidate.") do
      CompletionPopup.instance.select_previous
    end

    define_command(:completion_popup_accept,
                   doc: "Accept the selected completion.") do
      popup = CompletionPopup.instance
      item = popup.accept
      if item
        insert_completion(item)
      end
      completion_popup_done
    end

    define_command(:completion_popup_cancel,
                   doc: "Cancel completion popup.") do
      CompletionPopup.instance.cancel
      completion_popup_done
    end

    define_command(:completion_popup_self_insert_and_close,
                   doc: "Close popup and process the key.") do
      CompletionPopup.instance.close
      completion_popup_done
      # Execute the command for the key that closed the popup
      key = Controller.current.last_key
      buffer = Buffer.current
      cmd = buffer&.keymap&.lookup([key]) || GLOBAL_MAP.lookup([key])
      if cmd.is_a?(Symbol)
        send(cmd)
      elsif cmd.respond_to?(:call)
        cmd.call
      end
    end

    def completion_popup_start(items:, start_point:, prefix: "")
      return if items.empty?

      CompletionPopup.instance.show(
        items: items,
        start_point: start_point,
        prefix: prefix
      )

      COMPLETION_POPUP_STATUS[:active] = true
      COMPLETION_POPUP_STATUS[:start_point] = start_point

      Controller.current.overriding_map = COMPLETION_POPUP_MAP
      add_hook(:pre_command_hook, :completion_popup_pre_command_hook)
    end

    def completion_popup_done
      COMPLETION_POPUP_STATUS[:active] = false
      COMPLETION_POPUP_STATUS[:start_point] = nil
      Controller.current.overriding_map = nil
      remove_hook(:pre_command_hook, :completion_popup_pre_command_hook)
    end

    def completion_popup_pre_command_hook
      # Close popup if command is not a completion popup command
      if /\Acompletion_popup_/ !~ Controller.current.this_command.to_s
        CompletionPopup.instance.close
        completion_popup_done
      end
    end

    def insert_completion(item)
      buffer = Buffer.current
      start_point = COMPLETION_POPUP_STATUS[:start_point]
      return unless start_point

      # Get the text to insert
      insert_text = item[:insert_text] || item[:label]
      return unless insert_text

      # Delete the prefix that was already typed
      if buffer.point > start_point
        buffer.delete_region(start_point, buffer.point)
      end

      # Insert the completion
      buffer.insert(insert_text)
    end
  end
end
