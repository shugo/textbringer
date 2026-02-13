require_relative "../../test_helper"

class TestLSPClient < Textbringer::TestCase
  def test_normalize_completion_item
    client = create_client

    # Test with basic item
    item = {
      "label" => "foo",
      "insertText" => "foo()",
      "detail" => "Method",
      "kind" => 2
    }
    normalized = client.send(:normalize_completion_item, item)

    assert_equal("foo", normalized[:label])
    assert_equal("foo()", normalized[:insert_text])
    assert_equal("Method", normalized[:detail])
    assert_equal("Method", normalized[:kind])
  end

  def test_normalize_completion_item_without_insert_text
    client = create_client

    item = {
      "label" => "bar",
      "detail" => "Variable"
    }
    normalized = client.send(:normalize_completion_item, item)

    assert_equal("bar", normalized[:label])
    assert_equal("bar", normalized[:insert_text])  # Falls back to label
  end

  def test_normalize_completion_item_with_text_edit
    client = create_client

    item = {
      "label" => "baz",
      "textEdit" => { "newText" => "baz(arg)" }
    }
    normalized = client.send(:normalize_completion_item, item)

    assert_equal("baz", normalized[:label])
    assert_equal("baz(arg)", normalized[:insert_text])
  end

  def test_normalize_completion_result_with_array
    client = create_client

    result = [
      { "label" => "foo" },
      { "label" => "bar" }
    ]
    normalized = client.send(:normalize_completion_result, result)

    assert_equal(2, normalized.size)
    assert_equal("foo", normalized[0][:label])
    assert_equal("bar", normalized[1][:label])
  end

  def test_normalize_completion_result_with_completion_list
    client = create_client

    result = {
      "isIncomplete" => false,
      "items" => [
        { "label" => "foo" },
        { "label" => "bar" }
      ]
    }
    normalized = client.send(:normalize_completion_result, result)

    assert_equal(2, normalized.size)
    assert_equal("foo", normalized[0][:label])
    assert_equal("bar", normalized[1][:label])
  end

  def test_normalize_completion_result_nil
    client = create_client
    normalized = client.send(:normalize_completion_result, nil)
    assert_empty(normalized)
  end

  def test_completion_item_kind_name
    client = create_client

    assert_equal("Text", client.send(:completion_item_kind_name, 1))
    assert_equal("Method", client.send(:completion_item_kind_name, 2))
    assert_equal("Function", client.send(:completion_item_kind_name, 3))
    assert_equal("Class", client.send(:completion_item_kind_name, 7))
    assert_equal("Variable", client.send(:completion_item_kind_name, 6))
    assert_nil(client.send(:completion_item_kind_name, 999))
  end

  def test_client_capabilities
    client = create_client
    capabilities = client.send(:client_capabilities)

    assert(capabilities[:textDocument][:completion])
    assert(capabilities[:textDocument][:synchronization])
    refute(capabilities[:textDocument][:completion][:completionItem][:snippetSupport])

    # Signature help capabilities
    sig_help = capabilities[:textDocument][:signatureHelp]
    assert(sig_help)
    assert_equal(["plaintext"],
                 sig_help[:signatureInformation][:documentationFormat])
    assert(sig_help[:signatureInformation][:parameterInformation][:labelOffsetSupport])
  end

  def test_server_capabilities_initially_empty
    client = create_client
    assert_equal({}, client.server_capabilities)
  end

  def test_running_state_initially_false
    client = create_client
    refute(client.running?)
    refute(client.initialized?)
  end

  def test_document_open_tracking
    client = create_client

    refute(client.document_open?("file:///test.rb"))
  end

  private

  def create_client
    LSP::Client.new(
      command: "ruby",
      args: ["--version"],
      root_path: "/tmp"
    )
  end
end

class TestLSPServerRegistry < Textbringer::TestCase
  def setup
    super
    # Clear any existing registrations
    LSP::ServerRegistry.server_configs.clear
    LSP::ServerRegistry.instance_variable_get(:@clients).clear
  end

  def teardown
    LSP::ServerRegistry.stop_all_clients
    LSP::ServerRegistry.server_configs.clear
    super
  end

  def test_register
    config = LSP::ServerRegistry.register(
      "ruby",
      command: "solargraph",
      args: ["stdio"],
      file_patterns: [/\.rb$/]
    )

    assert_equal("ruby", config.language_id)
    assert_equal("solargraph", config.command)
    assert_equal(["stdio"], config.args)
    assert_equal([/\.rb$/], config.file_patterns)
    assert_nil(config.mode)
  end

  def test_register_with_mode
    config = LSP::ServerRegistry.register(
      "ruby",
      command: "ruby-lsp",
      args: [],
      mode: "Ruby"
    )

    assert_equal("ruby", config.language_id)
    assert_equal("ruby-lsp", config.command)
    assert_equal("Ruby", config.mode)
    assert_equal([], config.file_patterns)
  end

  def test_find_config_for_buffer
    LSP::ServerRegistry.register(
      "ruby",
      command: "solargraph",
      args: ["stdio"],
      file_patterns: [/\.rb$/]
    )

    mkcdtmpdir do |dir|
      file_path = File.join(dir, "test.rb")
      File.write(file_path, "puts 'hello'")

      buffer = Buffer.new_buffer("test.rb")
      buffer.instance_variable_set(:@file_name, file_path)

      config = LSP::ServerRegistry.find_config_for_buffer(buffer)
      assert_not_nil(config)
      assert_equal("ruby", config.language_id)
    end
  end

  def test_find_config_for_buffer_no_match
    LSP::ServerRegistry.register(
      "ruby",
      command: "solargraph",
      args: ["stdio"],
      file_patterns: [/\.rb$/]
    )

    mkcdtmpdir do |dir|
      file_path = File.join(dir, "test.py")
      File.write(file_path, "print('hello')")

      buffer = Buffer.new_buffer("test.py")
      buffer.instance_variable_set(:@file_name, file_path)

      config = LSP::ServerRegistry.find_config_for_buffer(buffer)
      assert_nil(config)
    end
  end

  def test_find_config_for_buffer_by_mode
    LSP::ServerRegistry.register(
      "ruby",
      command: "ruby-lsp",
      args: [],
      mode: "Ruby"
    )

    buffer = Buffer.new_buffer("test.rb")
    buffer.apply_mode(RubyMode)

    config = LSP::ServerRegistry.find_config_for_buffer(buffer)
    assert_not_nil(config)
    assert_equal("ruby", config.language_id)
  end

  def test_find_config_for_buffer_by_mode_without_filename
    LSP::ServerRegistry.register(
      "ruby",
      command: "ruby-lsp",
      args: [],
      mode: "Ruby"
    )

    buffer = Buffer.new_buffer("*scratch*")
    buffer.apply_mode(RubyMode)

    config = LSP::ServerRegistry.find_config_for_buffer(buffer)
    assert_not_nil(config)
    assert_equal("ruby", config.language_id)
  end

  def test_find_config_for_buffer_mode_takes_priority
    LSP::ServerRegistry.register(
      "ruby",
      command: "ruby-lsp",
      args: [],
      mode: "Ruby",
      file_patterns: [/\.rb$/]
    )

    # Mode matching should work even without a file name
    buffer = Buffer.new_buffer("*scratch*")
    buffer.apply_mode(RubyMode)

    config = LSP::ServerRegistry.find_config_for_buffer(buffer)
    assert_not_nil(config)
  end

  def test_find_config_for_buffer_without_filename
    buffer = Buffer.new_buffer("*scratch*")
    config = LSP::ServerRegistry.find_config_for_buffer(buffer)
    assert_nil(config)
  end

  def test_find_project_root_with_git
    mkcdtmpdir do |dir|
      # Create a nested directory structure
      nested = File.join(dir, "sub", "dir")
      FileUtils.mkdir_p(nested)

      # Create .git at the root
      FileUtils.mkdir_p(File.join(dir, ".git"))

      file_path = File.join(nested, "test.rb")
      File.write(file_path, "")

      root = LSP::ServerRegistry.find_project_root(file_path)
      assert_equal(dir, root)
    end
  end

  def test_find_project_root_with_gemfile
    mkcdtmpdir do |dir|
      nested = File.join(dir, "lib")
      FileUtils.mkdir_p(nested)

      File.write(File.join(dir, "Gemfile"), "")

      file_path = File.join(nested, "test.rb")
      File.write(file_path, "")

      root = LSP::ServerRegistry.find_project_root(file_path)
      assert_equal(dir, root)
    end
  end

  def test_find_project_root_fallback_to_file_directory
    mkcdtmpdir do |dir|
      # No markers present
      file_path = File.join(dir, "test.rb")
      File.write(file_path, "")

      root = LSP::ServerRegistry.find_project_root(file_path)
      assert_equal(dir, root)
    end
  end

  def test_unregister
    LSP::ServerRegistry.register(
      "ruby",
      command: "solargraph",
      args: ["stdio"],
      file_patterns: [/\.rb$/]
    )

    assert_equal(1, LSP::ServerRegistry.server_configs.size)

    LSP::ServerRegistry.unregister("ruby")

    assert_empty(LSP::ServerRegistry.server_configs)
  end

  def test_language_id_for_buffer
    LSP::ServerRegistry.register(
      "ruby",
      command: "solargraph",
      args: ["stdio"],
      file_patterns: [/\.rb$/]
    )

    mkcdtmpdir do |dir|
      file_path = File.join(dir, "test.rb")
      File.write(file_path, "")

      buffer = Buffer.new_buffer("test.rb")
      buffer.instance_variable_set(:@file_name, file_path)

      language_id = LSP::ServerRegistry.language_id_for_buffer(buffer)
      assert_equal("ruby", language_id)
    end
  end

  def test_language_id_for_buffer_no_match
    buffer = Buffer.new_buffer("test.unknown")
    buffer.instance_variable_set(:@file_name, "/tmp/test.unknown")

    language_id = LSP::ServerRegistry.language_id_for_buffer(buffer)
    assert_nil(language_id)
  end
end
