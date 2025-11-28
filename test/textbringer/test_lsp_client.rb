require_relative "../test_helper"

class TestLSPClient < Textbringer::TestCase
  def test_lsp_client_initialization
    client = LSPClient.new(command: ["ruby-lsp"], root_path: "/tmp")
    assert_equal("/tmp", client.instance_variable_get(:@root_path))
    assert_equal("file:///tmp", client.root_uri)
    assert_equal({}, client.server_capabilities)
    refute(client.running?)
  end

  def test_lsp_client_message_extraction
    client = LSPClient.new(command: ["ruby-lsp"], root_path: "/tmp")

    # Test valid message extraction
    buffer = String.new(encoding: "ASCII-8BIT")
    test_json = JSON.generate({ result: "test" })
    buffer << "Content-Length: #{test_json.bytesize}\r\n\r\n#{test_json}"

    message = client.send(:extract_message, buffer)
    assert_equal("test", message["result"])
    assert_equal("", buffer) # Buffer should be empty after extraction
  end

  def test_lsp_client_message_extraction_incomplete
    client = LSPClient.new(command: ["ruby-lsp"], root_path: "/tmp")

    # Test incomplete message (header only)
    buffer = String.new(encoding: "ASCII-8BIT")
    buffer << "Content-Length: 100\r\n\r\n"

    message = client.send(:extract_message, buffer)
    assert_nil(message)
    assert_equal("Content-Length: 100\r\n\r\n", buffer) # Buffer unchanged
  end

  def test_lsp_client_message_extraction_invalid_json
    client = LSPClient.new(command: ["ruby-lsp"], root_path: "/tmp")

    # Test invalid JSON
    buffer = String.new(encoding: "ASCII-8BIT")
    invalid_json = "not valid json"
    buffer << "Content-Length: #{invalid_json.bytesize}\r\n\r\n#{invalid_json}"

    message = client.send(:extract_message, buffer)
    assert_nil(message)
  end

  def test_lsp_client_client_capabilities
    client = LSPClient.new(command: ["ruby-lsp"], root_path: "/tmp")
    capabilities = client.send(:client_capabilities)

    assert(capabilities[:textDocument])
    assert(capabilities[:textDocument][:completion])
    assert(capabilities[:textDocument][:hover])
    assert_equal(["plaintext"], capabilities[:textDocument][:hover][:contentFormat])
  end

  def test_lsp_client_not_running_initially
    client = LSPClient.new(command: ["ruby-lsp"], root_path: "/tmp")
    refute(client.running?)
  end

  def test_lsp_client_stop_when_not_running
    client = LSPClient.new(command: ["ruby-lsp"], root_path: "/tmp")
    # Should not raise error
    assert_nothing_raised do
      client.stop
    end
  end
end
