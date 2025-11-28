require_relative "../test_helper"

class TestRubyLSPClient < Textbringer::TestCase
  def test_ruby_lsp_client_singleton
    client1 = RubyLSPClient.instance
    client2 = RubyLSPClient.instance
    assert_same(client1, client2)
  end

  def test_ruby_lsp_client_available
    # This test checks if ruby-lsp command is available
    # Result depends on whether ruby-lsp is installed
    result = RubyLSPClient.available?
    assert([true, false].include?(result))
  end

  def test_ruby_lsp_client_buffer_to_uri_with_file
    client = RubyLSPClient.new
    buffer = Buffer.new_buffer("test.rb")
    buffer.file_name = "/path/to/test.rb"

    uri = client.send(:buffer_to_uri, buffer)
    assert_equal("file:///path/to/test.rb", uri)
  end

  def test_ruby_lsp_client_buffer_to_uri_without_file
    client = RubyLSPClient.new
    buffer = Buffer.new_buffer("*scratch*")

    uri = client.send(:buffer_to_uri, buffer)
    assert(uri.start_with?("file://"))
    assert(uri.end_with?(".rb"))
  end

  def test_ruby_lsp_client_next_version
    client = RubyLSPClient.new

    uri = "file:///test.rb"
    version1 = client.send(:next_version, uri)
    assert_equal(1, version1)

    version2 = client.send(:next_version, uri)
    assert_equal(2, version2)

    version3 = client.send(:next_version, uri)
    assert_equal(3, version3)
  end

  def test_ruby_lsp_client_parse_completion_response_with_items
    client = RubyLSPClient.new

    response = {
      "result" => {
        "items" => [
          { "label" => "upcase", "kind" => 6 },
          { "label" => "upcase!", "kind" => 6 }
        ]
      }
    }

    completions = client.send(:parse_completion_response, response)
    assert_equal(2, completions.size)
    assert_equal("upcase", completions[0][:label])
    assert_equal("upcase!", completions[1][:label])
  end

  def test_ruby_lsp_client_parse_completion_response_with_array
    client = RubyLSPClient.new

    response = {
      "result" => [
        { "label" => "map", "kind" => 6 },
        { "label" => "max", "kind" => 6 }
      ]
    }

    completions = client.send(:parse_completion_response, response)
    assert_equal(2, completions.size)
    assert_equal("map", completions[0][:label])
    assert_equal("max", completions[1][:label])
  end

  def test_ruby_lsp_client_parse_completion_response_empty
    client = RubyLSPClient.new

    response = { "result" => nil }
    completions = client.send(:parse_completion_response, response)
    assert_equal([], completions)
  end

  def test_ruby_lsp_client_parse_hover_response_string
    client = RubyLSPClient.new

    response = {
      "result" => {
        "contents" => "String#upcase documentation"
      }
    }

    hover = client.send(:parse_hover_response, response)
    assert_equal("String#upcase documentation", hover)
  end

  def test_ruby_lsp_client_parse_hover_response_hash
    client = RubyLSPClient.new

    response = {
      "result" => {
        "contents" => {
          "value" => "Method documentation"
        }
      }
    }

    hover = client.send(:parse_hover_response, response)
    assert_equal("Method documentation", hover)
  end

  def test_ruby_lsp_client_parse_hover_response_array
    client = RubyLSPClient.new

    response = {
      "result" => {
        "contents" => [
          { "value" => "Line 1" },
          { "value" => "Line 2" }
        ]
      }
    }

    hover = client.send(:parse_hover_response, response)
    assert_equal("Line 1\nLine 2", hover)
  end

  def test_ruby_lsp_client_parse_hover_response_nil
    client = RubyLSPClient.new

    response = { "result" => nil }
    hover = client.send(:parse_hover_response, response)
    assert_nil(hover)
  end

  def test_ruby_lsp_client_find_project_root_with_gemfile
    client = RubyLSPClient.new

    Dir.mktmpdir do |dir|
      FileUtils.touch(File.join(dir, "Gemfile"))

      buffer = Buffer.new_buffer("test.rb")
      buffer.file_name = File.join(dir, "lib", "test.rb")
      old_buffer = Buffer.current
      Buffer.current = buffer

      begin
        root = client.send(:find_project_root)
        assert_equal(dir, root)
      ensure
        Buffer.current = old_buffer
      end
    end
  end

  def test_ruby_lsp_client_find_project_root_with_git
    client = RubyLSPClient.new

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, ".git"))

      buffer = Buffer.new_buffer("test.rb")
      buffer.file_name = File.join(dir, "app", "test.rb")
      old_buffer = Buffer.current
      Buffer.current = buffer

      begin
        root = client.send(:find_project_root)
        assert_equal(dir, root)
      ensure
        Buffer.current = old_buffer
      end
    end
  end

  def test_ruby_lsp_client_calculate_lsp_character
    client = RubyLSPClient.new
    buffer = Buffer.new_buffer("test.rb")
    buffer.insert("hello world")
    buffer.goto_char(6) # After "hello "

    character = client.send(:calculate_lsp_character, buffer)
    # current_column is 1-based, so at position 6 (0-indexed), column is 7
    assert_equal(7, character)
  end
end
