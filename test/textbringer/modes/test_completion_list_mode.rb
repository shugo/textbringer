require_relative "../../test_helper"

class TestCompletionListMode < Textbringer::TestCase
  def setup
    super
    @buffer = Buffer.new_buffer("*Completions*")
    @mode = CompletionListMode.new(@buffer)
    switch_to_buffer(@buffer)
  end

  def test_jump_to_location
    COMPLETION[:original_buffer] = Buffer["*scratch*"]
    COMPLETION[:completions_window] = Window.windows.first
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
    COMPLETION[:original_buffer] = nil
    COMPLETION[:completions_window] = nil
  end
end
