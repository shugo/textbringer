require "json"
require "open3"

module Textbringer
  # LSP Client for Language Server Protocol communication
  # Communicates with language servers via JSON-RPC over stdio
  class LSPClient
    include Utils

    attr_reader :server_name, :root_uri, :server_capabilities

    def initialize(command:, root_path: nil, initialization_options: {})
      @command = command
      @root_path = root_path || Dir.pwd
      @root_uri = "file://#{@root_path}"
      @initialization_options = initialization_options
      @message_id = 0
      @pending_requests = {}
      @stdin = nil
      @stdout = nil
      @stderr = nil
      @wait_thread = nil
      @reader_thread = nil
      @initialized = false
      @server_capabilities = {}
      @mutex = Mutex.new
    end

    # Start the language server process
    def start
      return if running?

      begin
        @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(*@command)
        @reader_thread = background { read_loop }
        initialize_server
      rescue Errno::ENOENT => e
        raise EditorError, "Failed to start LSP server: #{@command.join(' ')} not found"
      rescue => e
        raise EditorError, "Failed to start LSP server: #{e.message}"
      end
    end

    # Check if the server is running
    def running?
      @wait_thread && @wait_thread.alive?
    end

    # Stop the language server
    def stop
      return unless running?

      begin
        send_request("shutdown", {}, timeout: 2)
        send_notification("exit", {})
      rescue
        # Ignore errors during shutdown
      end

      @reader_thread&.kill
      @stdin&.close rescue nil
      @stdout&.close rescue nil
      @stderr&.close rescue nil
      @wait_thread = nil
      @initialized = false
      @pending_requests.clear
    end

    # Send a notification (no response expected)
    def send_notification(method, params)
      message = {
        jsonrpc: "2.0",
        method: method,
        params: params
      }
      write_message(message)
    end

    # Send a request and wait for response
    def send_request(method, params, timeout: 5)
      return nil unless running?

      id = @mutex.synchronize do
        @message_id += 1
        @message_id
      end

      message = {
        jsonrpc: "2.0",
        id: id,
        method: method,
        params: params
      }

      response_queue = Queue.new
      @mutex.synchronize do
        @pending_requests[id] = response_queue
      end

      write_message(message)

      # Wait for response with timeout
      begin
        Timeout.timeout(timeout) do
          response = response_queue.pop
          if response["error"]
            return nil
          end
          return response
        end
      rescue Timeout::Error
        @mutex.synchronize do
          @pending_requests.delete(id)
        end
        nil
      end
    end

    # Notify server of document open
    def did_open(uri:, language_id:, version:, text:)
      send_notification("textDocument/didOpen", {
        textDocument: {
          uri: uri,
          languageId: language_id,
          version: version,
          text: text
        }
      })
    end

    # Notify server of document change
    def did_change(uri:, version:, text:)
      send_notification("textDocument/didChange", {
        textDocument: {
          uri: uri,
          version: version
        },
        contentChanges: [
          {
            text: text
          }
        ]
      })
    end

    # Notify server of document close
    def did_close(uri:)
      send_notification("textDocument/didClose", {
        textDocument: {
          uri: uri
        }
      })
    end

    # Request completion
    def completion(uri:, line:, character:)
      send_request("textDocument/completion", {
        textDocument: {
          uri: uri
        },
        position: {
          line: line,
          character: character
        }
      }, timeout: 5)
    end

    # Request hover information
    def hover(uri:, line:, character:)
      send_request("textDocument/hover", {
        textDocument: {
          uri: uri
        },
        position: {
          line: line,
          character: character
        }
      })
    end

    private

    # Initialize the language server
    def initialize_server
      response = send_request("initialize", {
        processId: Process.pid,
        rootPath: @root_path,
        rootUri: @root_uri,
        capabilities: client_capabilities,
        initializationOptions: @initialization_options
      }, timeout: 10)

      if response && response["result"]
        @server_capabilities = response["result"]["capabilities"] || {}
        send_notification("initialized", {})
        @initialized = true
      else
        raise EditorError, "Failed to initialize LSP server"
      end
    end

    # Client capabilities declaration
    def client_capabilities
      {
        textDocument: {
          completion: {
            completionItem: {
              snippetSupport: false,
              documentationFormat: ["plaintext"]
            }
          },
          hover: {
            contentFormat: ["plaintext"]
          },
          synchronization: {
            didSave: false
          }
        },
        workspace: {
          applyEdit: false,
          workspaceEdit: {
            documentChanges: false
          }
        }
      }
    end

    # Write a JSON-RPC message to the server
    def write_message(message)
      return unless @stdin

      json = JSON.generate(message)
      content = json.encode("UTF-8")
      header = "Content-Length: #{content.bytesize}\r\n\r\n"

      @stdin.write(header)
      @stdin.write(content)
      @stdin.flush
    rescue => e
      # Ignore write errors if server is stopped
    end

    # Read loop for processing server messages
    # This runs in a background thread
    def read_loop
      buffer = String.new(encoding: "ASCII-8BIT")

      while running?
        begin
          # Check if stdout is ready to read
          rs, _, _ = IO.select([@stdout], nil, nil, 0.1)
          next unless rs

          chunk = @stdout.read_nonblock(4096)
          buffer << chunk

          while (message = extract_message(buffer))
            handle_message(message)
          end
        rescue EOFError, IOError
          break
        rescue IO::WaitReadable
          # No data available, continue loop
          next
        rescue => e
          # Log error but continue
          break
        end
      end
    end

    # Extract a complete LSP message from buffer
    def extract_message(buffer)
      # Look for Content-Length header
      if buffer =~ /\AContent-Length: (\d+)\r\n\r\n/
        content_length = $1.to_i
        header_end = $~.end(0)

        if buffer.bytesize >= header_end + content_length
          json = buffer.byteslice(header_end, content_length)
          buffer.slice!(0, header_end + content_length)

          begin
            return JSON.parse(json.force_encoding("UTF-8"))
          rescue JSON::ParserError
            return nil
          end
        end
      end

      nil
    end

    # Handle incoming message from server
    # This runs in background thread - no buffer manipulation!
    def handle_message(message)
      if message["id"]
        # This is a response to our request
        @mutex.synchronize do
          queue = @pending_requests.delete(message["id"])
          queue&.push(message)
        end
      elsif message["method"]
        # This is a notification or request from server
        handle_server_request(message)
      end
    end

    # Handle requests/notifications from server
    def handle_server_request(message)
      # Handle server-initiated requests like window/logMessage
      case message["method"]
      when "window/logMessage"
        # Could log to *Messages* buffer using foreground
        params = message["params"]
        if params && params["message"]
          # foreground do
          #   message(params["message"])
          # end
        end
      when "window/showMessage"
        # Similar to logMessage
      end
      # For now, we'll just ignore most server requests
    end
  end
end
