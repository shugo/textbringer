# frozen_string_literal: true

module Textbringer
  module LSP
    class ServerRegistry
      # Project root marker files/directories
      PROJECT_ROOT_MARKERS = %w[
        .git
        .hg
        .svn
        Gemfile
        package.json
        Cargo.toml
        go.mod
        setup.py
        pyproject.toml
        Makefile
        CMakeLists.txt
      ].freeze

      @server_configs = []
      @clients = {}

      class << self
        attr_reader :server_configs

        def register(language_id, command:, args: [], file_patterns: [], interpreter_patterns: [], mode: nil)
          config = ServerConfig.new(
            language_id: language_id,
            command: command,
            args: args,
            file_patterns: file_patterns,
            interpreter_patterns: interpreter_patterns,
            mode: mode
          )
          @server_configs << config
          config
        end

        def unregister(language_id)
          @server_configs.reject! { |c| c.language_id == language_id }
          # Stop any running clients for this language
          @clients.delete_if do |key, client|
            if key.start_with?("#{language_id}:")
              client.stop rescue nil
              true
            else
              false
            end
          end
        end

        def find_config_for_buffer(buffer)
          mode_name = buffer.mode&.name

          @server_configs.find do |config|
            if config.mode && mode_name
              config.mode == mode_name
            elsif buffer.file_name && !config.file_patterns.empty?
              config.file_patterns.any? { |pattern| pattern.match?(buffer.file_name) }
            else
              false
            end
          end
        end

        def get_client_for_buffer(buffer)
          config = find_config_for_buffer(buffer)
          return nil unless config

          root_path = find_project_root(buffer.file_name || Dir.pwd)
          client_key = "#{config.language_id}:#{root_path}"

          @clients[client_key] ||= begin
            client = Client.new(
              command: config.command,
              args: config.args,
              root_path: root_path,
              server_name: config.language_id
            )
            client.start
            client
          end
        end

        def stop_client_for_buffer(buffer)
          config = find_config_for_buffer(buffer)
          return unless config

          root_path = find_project_root(buffer.file_name || Dir.pwd)
          client_key = "#{config.language_id}:#{root_path}"

          client = @clients.delete(client_key)
          client&.stop
        end

        def stop_all_clients
          @clients.each_value do |client|
            client.stop rescue nil
          end
          @clients.clear
        end

        def find_project_root(file_path)
          dir = File.dirname(File.expand_path(file_path))

          while dir != "/"
            if PROJECT_ROOT_MARKERS.any? { |marker| File.exist?(File.join(dir, marker)) }
              return dir
            end
            parent = File.dirname(dir)
            break if parent == dir
            dir = parent
          end

          # Fallback to the file's directory
          File.dirname(File.expand_path(file_path))
        end

        def language_id_for_buffer(buffer)
          config = find_config_for_buffer(buffer)
          config&.language_id
        end
      end
    end

    class ServerConfig
      attr_reader :language_id, :command, :args, :file_patterns, :interpreter_patterns, :mode

      def initialize(language_id:, command:, args:, file_patterns:, interpreter_patterns:, mode:)
        @language_id = language_id
        @command = command
        @args = args
        @file_patterns = file_patterns
        @interpreter_patterns = interpreter_patterns
        @mode = mode
      end
    end
  end
end
