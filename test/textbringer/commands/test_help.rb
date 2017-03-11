require_relative "../../test_helper"

class TestHelp < Textbringer::TestCase
  def test_describe_bindings
    describe_bindings
    s = Buffer.current.to_s
    assert_match(/^a +self_insert/, s)
    assert_match(/^<backspace> +backward_delete_char/, s)
    assert_match(/^C-h +backward_delete_char/, s)
    assert_match(/^C-x RET f +set_buffer_file_encoding/, s)
  end

  def test_describe_command
    assert_raise(EditorError) do
      describe_command("no_such_command")
    end
    describe_command("describe_command")
    s = Buffer.current.to_s
    assert_match(/^describe_command\(name\)/, s)
    assert_match(/^Display the documentation of the command./, s)
  end

  def test_describe_key
    describe_key([:f1, "k"])
    s = Buffer.current.to_s
    assert_match(/^<f1> k runs the command describe_key/, s)
    assert_match(/^describe_key\(key\)/, s)
  end
end
