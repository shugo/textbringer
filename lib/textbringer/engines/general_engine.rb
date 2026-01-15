# frozen_string_literal: true

module Textbringer
  # GeneralEngine provides a Notepad-like editing experience with
  # standard keyboard shortcuts (Ctrl+S, Ctrl+C, Ctrl+V, etc.)
  class GeneralEngine < Engine
    register :general

    class << self
      def global_keymap = GENERAL_MAP

      def minibuffer_keymap = GENERAL_MINIBUFFER_MAP

      def supports_multi_stroke? = false

      def supports_prefix_arg? = false

      def supports_keyboard_macros? = false

      def buffer_features = []

      def selection_model = :shift_select

      def clipboard_model = :simple

      def setup
        setup_keymaps
        setup_commands
      end

      private

      def setup_keymaps
        setup_general_map
        setup_minibuffer_map
      end

      def setup_general_map
        # Self-insert for printable characters
        (0x20..0x7e).each do |c|
          GENERAL_MAP.define_key(c.chr, :self_insert)
        end

        # Basic editing
        GENERAL_MAP.define_key("\C-m", :newline)
        GENERAL_MAP.define_key("\t", :self_insert)
        GENERAL_MAP.define_key(:backspace, :backward_delete_char)
        GENERAL_MAP.define_key(:dc, :delete_char)
        GENERAL_MAP.define_key(?\C-h, :backward_delete_char)

        # Navigation
        GENERAL_MAP.define_key(:right, :forward_char)
        GENERAL_MAP.define_key(:left, :backward_char)
        GENERAL_MAP.define_key(:up, :previous_line)
        GENERAL_MAP.define_key(:down, :next_line)
        GENERAL_MAP.define_key(:home, :beginning_of_line)
        GENERAL_MAP.define_key(:end, :end_of_line)
        GENERAL_MAP.define_key(:ppage, :scroll_down)
        GENERAL_MAP.define_key(:npage, :scroll_up)

        # Standard shortcuts
        GENERAL_MAP.define_key("\C-s", :save_buffer)           # Ctrl+S = Save
        GENERAL_MAP.define_key("\C-o", :find_file)             # Ctrl+O = Open
        GENERAL_MAP.define_key("\C-z", :undo)                  # Ctrl+Z = Undo
        GENERAL_MAP.define_key("\C-y", :redo_command)          # Ctrl+Y = Redo
        GENERAL_MAP.define_key("\C-c", :general_copy)          # Ctrl+C = Copy
        GENERAL_MAP.define_key("\C-x", :general_cut)           # Ctrl+X = Cut
        GENERAL_MAP.define_key("\C-v", :general_paste)         # Ctrl+V = Paste
        GENERAL_MAP.define_key("\C-a", :general_select_all)    # Ctrl+A = Select All
        GENERAL_MAP.define_key("\C-f", :isearch_forward)       # Ctrl+F = Find
        GENERAL_MAP.define_key("\C-g", :keyboard_quit)         # Ctrl+G = Cancel
        GENERAL_MAP.define_key("\C-q", :exit_textbringer)      # Ctrl+Q = Quit
        GENERAL_MAP.define_key("\C-n", :general_new_buffer)    # Ctrl+N = New
        GENERAL_MAP.define_key("\C-w", :kill_buffer)           # Ctrl+W = Close

        # Shift+Arrow for selection (if terminal supports it)
        GENERAL_MAP.define_key(:sright, :general_shift_forward_char)
        GENERAL_MAP.define_key(:sleft, :general_shift_backward_char)
        GENERAL_MAP.define_key(:sup, :general_shift_previous_line)
        GENERAL_MAP.define_key(:sdown, :general_shift_next_line)
        GENERAL_MAP.define_key(:shome, :general_shift_beginning_of_line)
        GENERAL_MAP.define_key(:send, :general_shift_end_of_line)

        # Word navigation
        GENERAL_MAP.define_key("\M-f", :forward_word)
        GENERAL_MAP.define_key("\M-b", :backward_word)

        # F-keys
        GENERAL_MAP.define_key(:f1, :describe_bindings)
      end

      def setup_minibuffer_map
        # Self-insert for printable characters
        (0x20..0x7e).each do |c|
          GENERAL_MINIBUFFER_MAP.define_key(c.chr, :self_insert)
        end

        # Basic editing in minibuffer
        GENERAL_MINIBUFFER_MAP.define_key("\C-m", :exit_recursive_edit)
        GENERAL_MINIBUFFER_MAP.define_key(:backspace, :backward_delete_char)
        GENERAL_MINIBUFFER_MAP.define_key(?\C-h, :backward_delete_char)
        GENERAL_MINIBUFFER_MAP.define_key(:dc, :delete_char)

        # Navigation in minibuffer
        GENERAL_MINIBUFFER_MAP.define_key(:right, :forward_char)
        GENERAL_MINIBUFFER_MAP.define_key(:left, :backward_char)
        GENERAL_MINIBUFFER_MAP.define_key(:home, :beginning_of_line)
        GENERAL_MINIBUFFER_MAP.define_key(:end, :end_of_line)

        # Cancel
        GENERAL_MINIBUFFER_MAP.define_key("\C-g", :abort_recursive_edit)
        GENERAL_MINIBUFFER_MAP.define_key(:escape, :abort_recursive_edit)

        # Tab completion
        GENERAL_MINIBUFFER_MAP.define_key("\t", :complete_minibuffer)
      end

      def setup_commands
        # Simple copy - uses system clipboard
        Commands.define_command(:general_copy, doc: "Copy selection to clipboard") do
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
        Commands.define_command(:general_cut, doc: "Cut selection to clipboard") do
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
        Commands.define_command(:general_paste, doc: "Paste from clipboard") do
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
        Commands.define_command(:general_select_all, doc: "Select entire buffer") do
          buffer = Buffer.current
          buffer.end_of_buffer
          buffer.push_mark(buffer.point_min)
          buffer.activate_mark
          message("Selected all")
        end

        # New buffer
        Commands.define_command(:general_new_buffer, doc: "Create a new buffer") do
          buffer = Buffer.new
          switch_to_buffer(buffer)
        end

        # Shift+movement commands for selection
        Commands.define_command(:general_shift_forward_char, doc: "Extend selection forward") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.forward_char
        end

        Commands.define_command(:general_shift_backward_char, doc: "Extend selection backward") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.backward_char
        end

        Commands.define_command(:general_shift_previous_line, doc: "Extend selection up") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.previous_line
        end

        Commands.define_command(:general_shift_next_line, doc: "Extend selection down") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.next_line
        end

        Commands.define_command(:general_shift_beginning_of_line, doc: "Extend selection to beginning of line") do
          buffer = Buffer.current
          unless buffer.mark_active?
            buffer.set_mark
            buffer.activate_mark
          end
          buffer.beginning_of_line
        end

        Commands.define_command(:general_shift_end_of_line, doc: "Extend selection to end of line") do
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

  # Define keymaps for GeneralEngine
  define_keymap :GENERAL_MAP
  define_keymap :GENERAL_MINIBUFFER_MAP
end
