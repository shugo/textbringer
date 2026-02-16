# frozen_string_literal: true

module Textbringer
  # CuaEngine provides a Notepad-like editing experience with
  # standard keyboard shortcuts (Ctrl+S, Ctrl+C, Ctrl+V, etc.)
  class CuaEngine < Engine
    register :cua

    class << self
      def global_keymap = CUA_MAP

      def minibuffer_keymap = CUA_MINIBUFFER_MAP

      def supports_multi_stroke? = false

      def supports_prefix_arg? = false

      def supports_keyboard_macros? = false

      def buffer_features = []

      def selection_model = :shift_select

      def clipboard_model = :simple

      # Override process_key_event to prioritize CUA_MAP over mode keymaps
      # and ignore Keymap results (since multi-stroke is not supported)
      def process_key_event(controller, key_sequence)
        # Check overriding_map first (e.g., for minibuffer)
        if controller.overriding_map
          result = controller.overriding_map.lookup(key_sequence)
          return result if result.is_a?(Symbol)
        end

        # Check CUA_MAP with priority over mode keymaps
        result = CUA_MAP.lookup(key_sequence)
        return result if result.is_a?(Symbol)

        # Fall back to mode keymap
        result = Buffer.current&.keymap&.lookup(key_sequence)
        return result if result.is_a?(Symbol)

        # If nothing found, return nil (undefined)
        nil
      end

      def setup
        setup_keymaps
        setup_commands
        register_mark_preserving_commands
      end

      private

      def register_mark_preserving_commands
        # Register CUA commands that should preserve the mark with TransientMarkMode
        return unless defined?(TransientMarkMode)

        TransientMarkMode::MARK_PRESERVING_COMMANDS.merge([
          # Shift selection commands
          :cua_shift_forward_char,
          :cua_shift_backward_char,
          :cua_shift_next_line,
          :cua_shift_previous_line,
          :cua_shift_beginning_of_line,
          :cua_shift_end_of_line,
          # Clipboard commands (they handle deactivation themselves)
          :cua_copy,
          :cua_cut,
          :cua_select_all,
        ])
      end

      def setup_keymaps
        setup_cua_map
        setup_minibuffer_map
      end

      def setup_cua_map
        # Self-insert for printable characters
        (0x20..0x7e).each do |c|
          CUA_MAP.define_key(c.chr, :self_insert)
        end

        # Basic editing
        CUA_MAP.define_key("\C-m", :newline)
        CUA_MAP.define_key("\t", :self_insert)
        CUA_MAP.define_key(:backspace, :backward_delete_char)
        CUA_MAP.define_key(:dc, :delete_char)
        CUA_MAP.define_key(?\C-h, :backward_delete_char)

        # Navigation (CUA versions that clear selection)
        CUA_MAP.define_key(:right, :cua_forward_char)
        CUA_MAP.define_key(:left, :cua_backward_char)
        CUA_MAP.define_key(:up, :cua_previous_line)
        CUA_MAP.define_key(:down, :cua_next_line)
        CUA_MAP.define_key(:home, :cua_beginning_of_line)
        CUA_MAP.define_key(:end, :cua_end_of_line)
        CUA_MAP.define_key(:ppage, :scroll_down)
        CUA_MAP.define_key(:npage, :scroll_up)

        # Standard shortcuts
        CUA_MAP.define_key("\C-s", :save_buffer)           # Ctrl+S = Save
        CUA_MAP.define_key("\C-o", :find_file)             # Ctrl+O = Open
        CUA_MAP.define_key("\C-z", :undo)                  # Ctrl+Z = Undo
        CUA_MAP.define_key("\C-y", :redo_command)          # Ctrl+Y = Redo
        CUA_MAP.define_key("\C-c", :cua_copy)          # Ctrl+C = Copy
        CUA_MAP.define_key("\C-x", :cua_cut)           # Ctrl+X = Cut
        CUA_MAP.define_key("\C-v", :cua_paste)         # Ctrl+V = Paste
        CUA_MAP.define_key("\C-a", :cua_select_all)    # Ctrl+A = Select All
        CUA_MAP.define_key("\C-f", :isearch_forward)       # Ctrl+F = Find
        CUA_MAP.define_key("\C-g", :keyboard_quit)         # Ctrl+G = Cancel
        CUA_MAP.define_key("\C-q", :exit_textbringer)      # Ctrl+Q = Quit
        CUA_MAP.define_key("\C-n", :cua_new_buffer)    # Ctrl+N = New
        CUA_MAP.define_key("\C-w", :kill_buffer)           # Ctrl+W = Close

        # Shift+Arrow for selection (if terminal supports it)
        CUA_MAP.define_key(:sright, :cua_shift_forward_char)
        CUA_MAP.define_key(:sleft, :cua_shift_backward_char)
        CUA_MAP.define_key(:sup, :cua_shift_previous_line)
        CUA_MAP.define_key(:sdown, :cua_shift_next_line)
        # Alternative key codes for Shift+Up/Down (some terminals send these)
        CUA_MAP.define_key(:sr, :cua_shift_previous_line)   # scroll reverse = Shift+Up
        CUA_MAP.define_key(:sf, :cua_shift_next_line)       # scroll forward = Shift+Down
        CUA_MAP.define_key(:shome, :cua_shift_beginning_of_line)
        CUA_MAP.define_key(:send, :cua_shift_end_of_line)

        # Word navigation
        CUA_MAP.define_key("\M-f", :forward_word)
        CUA_MAP.define_key("\M-b", :backward_word)

        # F-keys
        CUA_MAP.define_key(:f1, :describe_bindings)
      end

      def setup_minibuffer_map
        # Self-insert for printable characters
        (0x20..0x7e).each do |c|
          CUA_MINIBUFFER_MAP.define_key(c.chr, :self_insert)
        end

        # Basic editing in minibuffer
        CUA_MINIBUFFER_MAP.define_key("\C-m", :exit_recursive_edit)
        CUA_MINIBUFFER_MAP.define_key(:backspace, :backward_delete_char)
        CUA_MINIBUFFER_MAP.define_key(?\C-h, :backward_delete_char)
        CUA_MINIBUFFER_MAP.define_key(:dc, :delete_char)

        # Navigation in minibuffer
        CUA_MINIBUFFER_MAP.define_key(:right, :forward_char)
        CUA_MINIBUFFER_MAP.define_key(:left, :backward_char)
        CUA_MINIBUFFER_MAP.define_key(:home, :beginning_of_line)
        CUA_MINIBUFFER_MAP.define_key(:end, :end_of_line)

        # Cancel
        CUA_MINIBUFFER_MAP.define_key("\C-g", :abort_recursive_edit)
        CUA_MINIBUFFER_MAP.define_key(:escape, :abort_recursive_edit)

        # Tab completion
        CUA_MINIBUFFER_MAP.define_key("\t", :complete_minibuffer)
      end

      def setup_commands
        # Simple copy - uses system clipboard
        Commands.define_command(:cua_copy, doc: "Copy selection to clipboard") do
          buffer = Buffer.current
          if buffer.mark_active?
            mark_pos = buffer.mark rescue nil
            if mark_pos && mark_pos != buffer.point
              s = [buffer.point, mark_pos].min
              e = [buffer.point, mark_pos].max
              text = buffer.substring(s, e)
              if defined?(Clipboard) && Commands::CLIPBOARD_AVAILABLE
                Clipboard.copy(text)
              end
              message("Copied #{e - s} characters")
              buffer.deactivate_mark
            else
              message("No selection")
            end
          else
            message("No selection")
          end
        end

        # Simple cut - uses system clipboard
        Commands.define_command(:cua_cut, doc: "Cut selection to clipboard") do
          buffer = Buffer.current
          if buffer.mark_active?
            mark_pos = buffer.mark rescue nil
            if mark_pos && mark_pos != buffer.point
              s = [buffer.point, mark_pos].min
              e = [buffer.point, mark_pos].max
              text = buffer.substring(s, e)
              if defined?(Clipboard) && Commands::CLIPBOARD_AVAILABLE
                Clipboard.copy(text)
              end
              buffer.delete_region(s, e)
              message("Cut #{e - s} characters")
              buffer.deactivate_mark
            else
              message("No selection")
            end
          else
            message("No selection")
          end
        end

        # Simple paste - uses system clipboard
        Commands.define_command(:cua_paste, doc: "Paste from clipboard") do
          buffer = Buffer.current
          # Delete selection first if exists
          if buffer.mark_active?
            mark_pos = buffer.mark rescue nil
            if mark_pos
              s = [buffer.point, mark_pos].min
              e = [buffer.point, mark_pos].max
              buffer.delete_region(s, e)
              buffer.deactivate_mark
            end
          end
          if defined?(Clipboard) && Commands::CLIPBOARD_AVAILABLE
            text = Clipboard.paste.encode(Encoding::UTF_8).gsub(/\r\n/, "\n")
            buffer.insert(text)
          else
            message("Clipboard not available")
          end
        end

        # Select all
        Commands.define_command(:cua_select_all, doc: "Select entire buffer") do
          buffer = Buffer.current
          buffer.end_of_buffer
          buffer.push_mark(buffer.point_min)
          buffer.activate_mark
          message("Selected all")
        end

        # New buffer
        Commands.define_command(:cua_new_buffer, doc: "Create a new buffer") do
          buffer = Buffer.new
          switch_to_buffer(buffer)
        end

        # Navigation commands that clear selection (standard CUA behavior)
        Commands.define_command(:cua_forward_char, doc: "Move forward, clearing selection") do
          buffer = Buffer.current
          buffer.deactivate_mark
          buffer.forward_char
        end

        Commands.define_command(:cua_backward_char, doc: "Move backward, clearing selection") do
          buffer = Buffer.current
          buffer.deactivate_mark
          buffer.backward_char
        end

        Commands.define_command(:cua_next_line, doc: "Move to next line, clearing selection") do
          buffer = Buffer.current
          buffer.deactivate_mark
          buffer.next_line
        end

        Commands.define_command(:cua_previous_line, doc: "Move to previous line, clearing selection") do
          buffer = Buffer.current
          buffer.deactivate_mark
          buffer.previous_line
        end

        Commands.define_command(:cua_beginning_of_line, doc: "Move to beginning of line, clearing selection") do
          buffer = Buffer.current
          buffer.deactivate_mark
          buffer.beginning_of_line
        end

        Commands.define_command(:cua_end_of_line, doc: "Move to end of line, clearing selection") do
          buffer = Buffer.current
          buffer.deactivate_mark
          buffer.end_of_line
        end

        # Shift+movement commands for selection
        Commands.define_command(:cua_shift_forward_char, doc: "Extend selection forward") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.forward_char
        end

        Commands.define_command(:cua_shift_backward_char, doc: "Extend selection backward") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.backward_char
        end

        Commands.define_command(:cua_shift_previous_line, doc: "Extend selection up") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.previous_line
        end

        Commands.define_command(:cua_shift_next_line, doc: "Extend selection down") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.next_line
        end

        Commands.define_command(:cua_shift_beginning_of_line, doc: "Extend selection to beginning of line") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.beginning_of_line
        end

        Commands.define_command(:cua_shift_end_of_line, doc: "Extend selection to end of line") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.end_of_line
        end
      end
    end
  end

  # Define keymaps for CuaEngine
  define_keymap :CUA_MAP
  define_keymap :CUA_MINIBUFFER_MAP
end
