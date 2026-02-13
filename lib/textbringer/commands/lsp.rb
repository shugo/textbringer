# frozen_string_literal: true

module Textbringer
  module Commands
    LSP_DOCUMENT_VERSIONS = {}

    define_command(:lsp_completion, doc: <<~DOC) do
      Request completion from the Language Server Protocol server.
      Uses M-Tab (Alt+Tab) as the default keybinding.
    DOC
      buffer = Buffer.current

      client = LSP::ServerRegistry.get_client_for_buffer(buffer)
      unless client
        raise EditorError, "No LSP server configured for this buffer"
      end

      unless client.running? && client.initialized?
        message("LSP server not ready, please try again")
        return
      end

      unless client.document_open?(buffer_uri(buffer))
        lsp_open_document(buffer)
      end

      # Get completion position
      uri = buffer_uri(buffer)
      pos = lsp_position(buffer, buffer.point)
      line = pos[:line]
      character = pos[:character]

      # Calculate the start point for completion (beginning of current word)
      start_point = buffer.save_point do
        buffer.skip_re_backward(buffer.mode.symbol_pattern)
        buffer.point
      end

      # Get prefix already typed
      prefix = buffer.substring(start_point, buffer.point)

      # Request completion
      client.completion(uri: uri, line: line, character: character) do |items, error|
        if error
          message("LSP completion error: #{error["message"]}")
        elsif items && !items.empty?
          # Sort by sort_text (LSP server already filtered based on position)
          sorted_items = items.sort_by { |item| item[:sort_text] || item[:label] }

          completion_popup_start(
            items: sorted_items,
            start_point: start_point,
            prefix: prefix
          )
        else
          message("No completions found")
        end
      end
    end

    define_command(:lsp_ensure_started, doc: <<~DOC) do
      Start the LSP server for the current buffer if not already running.
    DOC
      buffer = Buffer.current

      client = LSP::ServerRegistry.get_client_for_buffer(buffer)
      if client
        if client.running?
          message("LSP server already running")
        else
          message("Starting LSP server...")
        end
      else
        message("No LSP server configured for this buffer")
      end
    end

    define_command(:lsp_stop, doc: <<~DOC) do
      Stop the LSP server for the current buffer.
    DOC
      buffer = Buffer.current
      LSP::ServerRegistry.stop_client_for_buffer(buffer)
      message("LSP server stopped")
    end

    define_command(:lsp_restart, doc: <<~DOC) do
      Restart the LSP server for the current buffer.
    DOC
      buffer = Buffer.current
      LSP::ServerRegistry.stop_client_for_buffer(buffer)
      client = LSP::ServerRegistry.get_client_for_buffer(buffer)
      if client
        message("LSP server restarting...")
      else
        message("No LSP server configured for this file type")
      end
    end

    # Helper methods

    # Convert a string's character length to UTF-16 code unit count.
    # LSP positions use UTF-16 offsets by default.
    def lsp_utf16_length(str)
      str.encode("UTF-16LE").bytesize / 2
    end

    # Compute LSP position (0-based line, UTF-16 character offset)
    # from a buffer position.
    def lsp_position(buffer, pos)
      line, = buffer.pos_to_line_and_column(pos)
      # Get the text from the start of the line to compute UTF-16 offset
      line_start = buffer.save_point do
        buffer.goto_char(pos)
        buffer.beginning_of_line
        buffer.point
      end
      text_on_line = buffer.substring(line_start, pos)
      character = lsp_utf16_length(text_on_line)
      { line: line - 1, character: character }
    end

    def buffer_uri(buffer)
      if buffer.file_name
        "file://#{buffer.file_name}"
      else
        "untitled:#{buffer.name}"
      end
    end

    def lsp_open_document(buffer)
      client = LSP::ServerRegistry.get_client_for_buffer(buffer)
      return unless client
      return unless client.running? && client.initialized?

      uri = buffer_uri(buffer)
      return if client.document_open?(uri)

      version = 1
      LSP_DOCUMENT_VERSIONS[uri] = version
      language_id = LSP::ServerRegistry.language_id_for_buffer(buffer) || "text"
      client.did_open(
        uri: uri,
        language_id: language_id,
        version: version,
        text: buffer.to_s
      )
      unless buffer[:lsp_hooks_installed]
        lsp_setup_buffer_hooks(buffer, client, uri)
        buffer[:lsp_hooks_installed] = true
      end
    end

    # Set up buffer hooks for document synchronization
    def lsp_setup_buffer_hooks(buffer, client, uri)
      # Track changes and send incremental updates to LSP server
      add_hook(:after_change_functions, local: true) do |beg_pos, end_pos, old_text|
        next unless client.running? && client.document_open?(uri)

        version = LSP_DOCUMENT_VERSIONS[uri] || 0
        version += 1
        LSP_DOCUMENT_VERSIONS[uri] = version

        # Compute start position in LSP coordinates (0-based, UTF-16)
        start_pos = lsp_position(buffer, beg_pos)

        if old_text.empty?
          # Insertion: old range is empty, new text is the inserted content
          new_text = buffer.substring(beg_pos, end_pos)
          range = { start: start_pos, end: start_pos }
        else
          # Deletion: compute old end position from the deleted text
          newline_count = old_text.count("\n")
          if newline_count == 0
            end_line = start_pos[:line]
            end_char = start_pos[:character] + lsp_utf16_length(old_text)
          else
            end_line = start_pos[:line] + newline_count
            last_newline = old_text.rindex("\n")
            end_char = lsp_utf16_length(old_text[last_newline + 1..])
          end
          range = {
            start: start_pos,
            end: { line: end_line, character: end_char }
          }
          new_text = ""
        end

        client.did_change(
          uri: uri, version: version,
          text: new_text, range: range
        )
      end

      # Close document when buffer is killed
      buffer.on_killed do
        if client.running?
          client.did_close(uri: uri)
          LSP_DOCUMENT_VERSIONS.delete(uri)
        end
      end
    end

    # Keybinding: M-Tab for LSP completion
    GLOBAL_MAP.define_key("\M-\t", :lsp_completion)

    # Open document with LSP server when a file is opened
    HOOKS[:find_file_hook].unshift(:lsp_find_file_hook)

    def lsp_find_file_hook
      lsp_open_document(Buffer.current)
    end

    # Reopen document when file name changes
    HOOKS[:after_set_visited_file_name_hook].unshift(
      :lsp_after_set_visited_file_name_hook
    )

    def lsp_after_set_visited_file_name_hook(old_file_name)
      buffer = Buffer.current

      # Close the old document
      old_uri = old_file_name ? "file://#{old_file_name}" : nil
      return unless old_uri
      client = LSP::ServerRegistry.get_client_for_buffer(buffer)
      if client&.running? && client.document_open?(old_uri)
        client.did_close(uri: old_uri)
        LSP_DOCUMENT_VERSIONS.delete(old_uri)
      end

      # Reset hooks so they are reinstalled with the new URI
      buffer[:lsp_hooks_installed] = false

      # Open the new document
      lsp_open_document(buffer)
    end
  end
end
