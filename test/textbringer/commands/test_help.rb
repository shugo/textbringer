require_relative "../../test_helper"

class TestHelp < Textbringer::TestCase
  def test_describe_bindings
    describe_bindings
    s = Buffer.current.to_s
    assert_match(/^<backspace> +\[backward_delete_char\]/, s)
    assert_match(/^C-h +\[backward_delete_char\]/, s)
    assert_match(/^C-x RET f +\[set_buffer_file_encoding\]/, s)
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

  def test_help_commands
    describe_bindings
    re_search_forward(/enlarge_window/)
    jump_to_link_command
    assert_match(/^enlarge_window\(n\)/, Buffer.current.to_s)
    jump_to_link_command
    assert_match(%r'lib/textbringer/commands/windows\.rb\z',
                 Buffer.current.file_name)
    switch_to_buffer("*Help*")
    re_search_forward(/shrink_window/)
    jump_to_link_command
    assert_match(/^shrink_window\(n\)/, Buffer.current.to_s)
    end_of_buffer
    jump_to_link_command
    assert_match(/^shrink_window\(n\)/, Buffer.current.to_s)
    help_go_back
    assert_match(/^enlarge_window\(n\)/, Buffer.current.to_s)
    help_go_back
    assert_match(/^Key\s+Binding/, Buffer.current.to_s)
    help_go_forward
    assert_match(/^enlarge_window\(n\)/, Buffer.current.to_s)
    help_go_forward
    assert_match(/^shrink_window\(n\)/, Buffer.current.to_s)
  end
end
