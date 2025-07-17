require_relative "../../test_helper"

class TestCompletionListMode < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("*Completions*")
    @mode = CompletionListMode.new(@buffer)
    switch_to_buffer(@buffer)
  end

  def test_jump_to_location
    Window.list.last.split
    COMPLETION[:completions_window] = Window.list.last
    @buffer.insert(<<EOF)
foo
bar
baz
EOF
    @buffer.goto_line(2)
    assert_raise(EditorError) do
      @mode.choose_completion
    end
    Window.echo_area.active = true
    @mode.choose_completion
    assert_equal("bar", Buffer.minibuffer.to_s)
  ensure
    COMPLETION[:completions_window] = nil
  end
end
