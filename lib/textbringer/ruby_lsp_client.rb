module Textbringer
  # Ruby-specific LSP client wrapper
  # Manages ruby-lsp server lifecycle and provides Ruby-specific helpers
  class RubyLSPClient
    include Utils

    @@instance = nil
    @@instance_mutex = Mutex.new

    attr_reader :lsp_client

    # Get or create singleton instance for the workspace
    def self.instance
      @@instance_mutex.synchronize do
        @@instance ||= new
      end
    end

    # Check if ruby-lsp is available
    def self.available?
      # Check if ruby-lsp command exists
      command = CONFIG[:ruby_lsp_command] || ["ruby-lsp"]
      system(*command, "--version", out: File::NULL, err: File::NULL, exception: false)
    rescue
      false
    end

    def initialize
      @lsp_client = nil
      @document_versions = {}
      @opened_documents = {}
      @mutex = Mutex.new
    end

    # Ensure the LSP client is started
    def ensure_started
      return if @lsp_client&.running?

      command = CONFIG[:ruby_lsp_command] || ["ruby-lsp"]
      root_path = find_project_root
      init_options = CONFIG[:ruby_lsp_initialization_options] || {}

      @lsp_client = LSPClient.new(
        command: command,
        root_path: root_path,
        initialization_options: init_options
      )

      @lsp_client.start
    end

    # Stop the LSP client
    def stop
      if @lsp_client
        @lsp_client.stop
        @lsp_client = nil
        @document_versions.clear
        @opened_documents.clear
      end
    end

    # Synchronize buffer with LSP server
    def sync_buffer(buffer)
      ensure_started
      return unless @lsp_client&.running?

      uri = buffer_to_uri(buffer)
      version = next_version(uri)
      text = buffer.to_s

      @mutex.synchronize do
        if @opened_documents[uri]
          # Document already open, send change
          @lsp_client.did_change(uri: uri, version: version, text: text)
        else
          # First time, send open
          @lsp_client.did_open(
            uri: uri,
            language_id: "ruby",
            version: version,
            text: text
          )
          @opened_documents[uri] = true
        end
      end
    end

    # Get completions at current position
    def get_completions(buffer)
      ensure_started
      return [] unless @lsp_client&.running?

      sync_buffer(buffer)

      uri = buffer_to_uri(buffer)
      line = buffer.current_line - 1  # LSP uses 0-based lines
      character = calculate_lsp_character(buffer)

      response = @lsp_client.completion(uri: uri, line: line, character: character)
      return [] unless response

      parse_completion_response(response)
    end

    # Get hover information
    def get_hover(buffer)
      ensure_started
      return nil unless @lsp_client&.running?

      sync_buffer(buffer)

      uri = buffer_to_uri(buffer)
      line = buffer.current_line - 1  # LSP uses 0-based lines
      character = calculate_lsp_character(buffer)

      response = @lsp_client.hover(uri: uri, line: line, character: character)
      return nil unless response

      parse_hover_response(response)
    end

    private

    # Convert buffer to file:// URI
    def buffer_to_uri(buffer)
      if buffer.file_name
        "file://#{File.expand_path(buffer.file_name)}"
      else
        # For unsaved buffers, use a temporary URI
        "file://#{Dir.pwd}/#{buffer.name.gsub(/[^a-zA-Z0-9_-]/, '_')}.rb"
      end
    end

    # Get next version number for a document
    def next_version(uri)
      @mutex.synchronize do
        @document_versions[uri] ||= 0
        @document_versions[uri] += 1
      end
    end

    # Calculate LSP character position (UTF-16 code units)
    # LSP uses UTF-16 code units, but for ASCII and most common cases,
    # column position works fine. For full correctness, we'd need to
    # convert UTF-8 to UTF-16 offsets.
    def calculate_lsp_character(buffer)
      # For now, use simple column-based calculation
      # This works correctly for ASCII and most common Ruby code
      buffer.current_column
    end

    # Find project root (look for Gemfile, .git, etc.)
    def find_project_root
      current_dir = if Buffer.current.file_name
        File.dirname(File.expand_path(Buffer.current.file_name))
      else
        Dir.pwd
      end

      # Look for project markers
      markers = ["Gemfile", ".git", ".ruby-lsp"]

      path = current_dir
      loop do
        markers.each do |marker|
          marker_path = File.join(path, marker)
          if File.exist?(marker_path)
            return path
          end
        end

        parent = File.dirname(path)
        break if parent == path  # reached root
        path = parent
      end

      # Default to current directory
      current_dir
    end

    # Parse completion response from LSP server
    def parse_completion_response(response)
      result = response["result"]
      return [] unless result

      items = if result.is_a?(Hash) && result["items"]
        result["items"]
      elsif result.is_a?(Array)
        result
      else
        []
      end

      items.map { |item|
        label = item["label"] || item["insertText"] || ""
        {
          label: label,
          kind: item["kind"],
          detail: item["detail"],
          documentation: item["documentation"],
          insert_text: item["insertText"] || label
        }
      }.compact
    end

    # Parse hover response from LSP server
    def parse_hover_response(response)
      result = response["result"]
      return nil unless result

      contents = result["contents"]
      return nil unless contents

      if contents.is_a?(String)
        contents
      elsif contents.is_a?(Hash)
        contents["value"] || contents.to_s
      elsif contents.is_a?(Array)
        contents.map { |c|
          c.is_a?(String) ? c : c["value"]
        }.compact.join("\n")
      else
        nil
      end
    end
  end
end
