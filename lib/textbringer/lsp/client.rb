require "open3"
require "json"
require "securerandom"

module Textbringer
  module LSP
    class Client
      class ServerError < StandardError; end
      class TimeoutError < StandardError; end

      attr_reader :root_path, :server_name, :server_capabilities

      def initialize(command:, args: [], root_path:, server_name: nil, workspace_folders: nil)
        @command = command
        @args = args
        @root_path = root_path
        @server_name = server_name || command
        @workspace_folders = Array(workspace_folders || @root_path)
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @wait_thr = nil
        @request_id = 0
        @pending_requests = {}
        @running = false
        @initialized = false
        @reader_thread = nil
        @mutex = Mutex.new
        @open_documents = {}
        @server_capabilities = {}
      end

      def start
        return if @running

        begin
          # Use Bundler's clean environment if available
          if defined?(Bundler)
            Bundler.with_unbundled_env do
              @stdin, @stdout, @stderr, @wait_thr =
                Open3.popen3(@command, *@args)
            end
          else
            @stdin, @stdout, @stderr, @wait_thr =
              Open3.popen3(@command, *@args)
          end
        rescue Errno::ENOENT
          Utils.message("LSP server command not found: #{@command}")
          return
        end

        @running = true
        initialize_server_sync
        start_reader_thread
      end

      def stop
        return unless @running

        shutdown
        exit_server
        cleanup
      end

      def running?
        @running
      end

      def initialized?
        @initialized
      end

      # Document synchronization

      def did_open(uri:, language_id:, version:, text:)
        return unless @initialized

        send_notification("textDocument/didOpen", {
          textDocument: {
            uri: uri,
            languageId: language_id,
            version: version,
            text: text
          }
        })
        @open_documents[uri] = version
      end

      def did_change(uri:, version:, text: nil, range: nil, range_length: nil)
        return unless @initialized
        return unless @open_documents.key?(uri)

        # Support both full and incremental sync
        content_change = if range
                           # Incremental change
                           change = { range: range }
                           change[:rangeLength] = range_length if range_length
                           change[:text] = text if text
                           change
                         else
                           # Full document sync
                           { text: text }
                         end

        send_notification("textDocument/didChange", {
          textDocument: {
            uri: uri,
            version: version
          },
          contentChanges: [content_change]
        })
        @open_documents[uri] = version
      end

      def did_close(uri:)
        return unless @initialized
        return unless @open_documents.key?(uri)

        send_notification("textDocument/didClose", {
          textDocument: { uri: uri }
        })
        @open_documents.delete(uri)
      end

      def document_open?(uri)
        @open_documents.key?(uri)
      end

      # Completion

      def completion(uri:, line:, character:, context: nil, &callback)
        return unless @initialized

        params = {
          textDocument: { uri: uri },
          position: { line: line, character: character }
        }
        params[:context] = context if context

        send_request("textDocument/completion", params) do |result, error|
          if error
            callback.call(nil, error) if callback
          else
            items = normalize_completion_result(result)
            callback.call(items, nil) if callback
          end
        end
      end

      # Signature Help

      def signature_help(uri:, line:, character:, context: nil, &callback)
        return unless @initialized

        params = {
          textDocument: { uri: uri },
          position: { line: line, character: character }
        }
        params[:context] = context if context

        send_request("textDocument/signatureHelp", params) do |result, error|
          callback.call(result, error) if callback
        end
      end

      private

      def initialize_server_sync
        @request_id += 1
        id = @request_id

        message = {
          jsonrpc: "2.0",
          id: id,
          method: "initialize",
          params: {
            processId: Process.pid,
            rootUri: "file://#{@root_path}",
            rootPath: @root_path,
            workspaceFolders: @workspace_folders.map { |path|
              { uri: "file://#{path}", name: File.basename(path) }
            },
            capabilities: client_capabilities,
            trace: "off"
          }
        }

        write_message(message)

        # Check if process is running
        unless @wait_thr&.alive?
          stderr_output = @stderr&.read rescue ""
          Utils.message("LSP server failed to start: #{stderr_output.strip}")
          cleanup
          return
        end

        # Read messages synchronously until we get the initialize response.
        # Server requests (e.g. window/workDoneProgress/create) that arrive
        # before the response are handled inline.
        timeout = Time.now + 5  # 5 second timeout
        loop do
          if Time.now > timeout
            stderr_output = @stderr&.read_nonblock(1000, exception: false) rescue ""
            Utils.message("LSP initialization timeout. stderr: #{stderr_output}")
            cleanup
            return
          end

          # Check if data is available to read (non-blocking check)
          readable, = IO.select([@stdout], nil, nil, 0.1)
          next unless readable

          msg = read_message
          unless msg
            # Check if process died
            unless @wait_thr&.alive?
              stderr_output = @stderr&.read rescue ""
              Utils.message("LSP server died: #{stderr_output.strip}")
              cleanup
              return
            end
            next
          end

          if msg.key?("id") && msg["id"] == id
            # This is the initialize response
            if msg.key?("error")
              Utils.message(
                "LSP initialization failed: #{msg["error"]["message"]}"
              )
              cleanup
            else
              @server_capabilities = msg["result"]["capabilities"] || {}
              @initialized = true
              send_notification("initialized", {})
              Utils.message("LSP server #{@server_name} initialized")
            end
            return
          elsif msg.key?("id") && msg.key?("method")
            # Server request during initialization - handle it
            handle_server_request(msg)
          end
          # Skip notifications during initialization
        end
      end

      def client_capabilities
        {
          textDocument: {
            completion: {
              completionItem: {
                snippetSupport: false,
                deprecatedSupport: true,
                labelDetailsSupport: true
              },
              completionItemKind: {
                valueSet: (1..25).to_a
              }
            },
            signatureHelp: {
              signatureInformation: {
                documentationFormat: ["plaintext"],
                parameterInformation: {
                  labelOffsetSupport: true
                }
              },
              contextSupport: true
            },
            synchronization: {
              didSave: true,
              willSave: false,
              willSaveWaitUntil: false,
              dynamicRegistration: false
            }
          },
          workspace: {
            workspaceFolders: true
          }
        }
      end

      def shutdown
        return unless @initialized

        shutdown_cv = ConditionVariable.new
        send_request("shutdown", nil) do |_result, _error|
          @mutex.synchronize do
            @initialized = false
            shutdown_cv.signal
          end
        end

        # Wait for shutdown response with timeout
        @mutex.synchronize do
          shutdown_cv.wait(@mutex, 3) if @initialized
        end
      end

      def exit_server
        send_notification("exit", nil)
      end

      def cleanup
        @mutex.synchronize do
          @running = false
          @initialized = false
          @pending_requests.clear
          @open_documents.clear
        end

        # Close IO streams first so reader thread exits naturally
        @stdin&.close rescue nil
        @stdout&.close rescue nil
        @stderr&.close rescue nil
        @stdin = @stdout = @stderr = nil

        # Wait for reader thread to finish, then force kill if needed
        if @reader_thread && @reader_thread != Thread.current
          @reader_thread.join(1)
          @reader_thread.kill if @reader_thread.alive?
        end
        @reader_thread = nil
      end

      def send_request(method, params, &callback)
        @mutex.synchronize do
          @request_id += 1
          id = @request_id

          message = {
            jsonrpc: "2.0",
            id: id,
            method: method,
            params: params
          }

          @pending_requests[id] = callback if callback
          write_message(message)
          id
        end
      end

      def send_notification(method, params)
        @mutex.synchronize do
          message = {
            jsonrpc: "2.0",
            method: method,
            params: params
          }
          write_message(message)
        end
      end

      # NOTE: Callers must hold @mutex when calling this method.
      def write_message(message)
        return unless @stdin && !@stdin.closed?

        json = message.to_json
        header = "Content-Length: #{json.bytesize}\r\n\r\n"

        @stdin.write(header)
        @stdin.write(json)
        @stdin.flush
      rescue IOError, Errno::EPIPE => e
        Utils.message("LSP write error: #{e.message}")
        @running = false
        @initialized = false
      end

      def start_reader_thread
        @reader_thread = Thread.new do
          read_messages
        rescue StandardError => e
          Utils.foreground do
            Utils.message("LSP reader error: #{e.message}")
          end
          cleanup
        end
      end

      def read_messages
        while @running && @stdout && !@stdout.closed?
          message = read_message
          break unless message

          Utils.foreground do
            handle_message(message)
          end
        end
      end

      def read_message
        # Read headers
        headers = {}
        while (line = @stdout.gets)
          line = line.strip
          break if line.empty?

          if line =~ /\A([^:]+):\s*(.+)\z/
            headers[$1] = $2
          end
        end

        return nil if headers.empty?

        # Read content
        content_length = headers["Content-Length"]&.to_i
        return nil unless content_length && content_length > 0

        content = @stdout.read(content_length)
        return nil unless content

        JSON.parse(content)
      rescue JSON::ParserError => e
        Utils.foreground do
          Utils.message("LSP JSON parse error: #{e.message}")
        end
        nil
      rescue IOError
        nil
      end

      def handle_message(message)
        if message.key?("id") && message.key?("method")
          # Request from server
          handle_server_request(message)
        elsif message.key?("id")
          # Response to our request
          handle_response(message)
        else
          # Notification from server
          handle_notification(message)
        end
      end

      def handle_response(message)
        id = message["id"]
        callback = @mutex.synchronize { @pending_requests.delete(id) }
        return unless callback

        if message.key?("error")
          callback.call(nil, message["error"])
        else
          callback.call(message["result"], nil)
        end
      end

      def handle_server_request(message)
        # Handle server-initiated requests
        id = message["id"]
        method = message["method"]

        case method
        when "window/workDoneProgress/create"
          # Accept progress token creation
          send_response(id, nil, nil)
        when "client/registerCapability"
          # Accept capability registration
          send_response(id, nil, nil)
        when "workspace/workspaceFolders"
          folders = @workspace_folders.map { |path|
            { uri: "file://#{path}", name: File.basename(path) }
          }
          send_response(id, folders, nil)
        else
          # Unknown request - respond with method not found
          send_response(id, nil, {
            code: -32601,
            message: "Method not found: #{method}"
          })
        end
      end

      def handle_notification(message)
        method = message["method"]
        params = message["params"]

        case method
        when "window/logMessage", "window/showMessage"
          type = params["type"]
          text = params["message"]
          # Log messages (type: 1=Error, 2=Warning, 3=Info, 4=Log)
          if type <= 2
            Utils.message("[LSP] #{text}")
          end
        when "textDocument/publishDiagnostics"
          # Could be used for error highlighting in the future
        end
      end

      def send_response(id, result, error)
        @mutex.synchronize do
          message = {
            jsonrpc: "2.0",
            id: id
          }

          if error
            message[:error] = error
          else
            message[:result] = result
          end

          write_message(message)
        end
      end

      def normalize_completion_result(result)
        return [] if result.nil?

        items = if result.is_a?(Array)
                  result
                elsif result.is_a?(Hash) && result["items"]
                  result["items"]
                else
                  []
                end

        items.map { |item| normalize_completion_item(item) }
      end

      def normalize_completion_item(item)
        {
          label: item["label"],
          insert_text: item["insertText"] || item["textEdit"]&.dig("newText") || item["label"],
          detail: item["detail"],
          kind: completion_item_kind_name(item["kind"]),
          sort_text: item["sortText"] || item["label"],
          filter_text: item["filterText"] || item["label"]
        }
      end

      COMPLETION_ITEM_KINDS = {
        1 => "Text",
        2 => "Method",
        3 => "Function",
        4 => "Constructor",
        5 => "Field",
        6 => "Variable",
        7 => "Class",
        8 => "Interface",
        9 => "Module",
        10 => "Property",
        11 => "Unit",
        12 => "Value",
        13 => "Enum",
        14 => "Keyword",
        15 => "Snippet",
        16 => "Color",
        17 => "File",
        18 => "Reference",
        19 => "Folder",
        20 => "EnumMember",
        21 => "Constant",
        22 => "Struct",
        23 => "Event",
        24 => "Operator",
        25 => "TypeParameter"
      }.freeze

      def completion_item_kind_name(kind)
        COMPLETION_ITEM_KINDS[kind]
      end
    end
  end
end
