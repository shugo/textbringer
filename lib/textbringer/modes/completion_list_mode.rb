module Textbringer
  class CompletionListMode < Mode
    define_generic_command :choose_completion

    define_keymap :COMPLETION_LIST_MODE_MAP
    COMPLETION_LIST_MODE_MAP.define_key("\C-m", :choose_completion_command)

    define_syntax :link, /^.+$/

    def initialize(buffer)
      super(buffer)
      buffer.keymap = COMPLETION_LIST_MODE_MAP
    end

    def choose_completion
      unless Window.echo_area.active?
        raise EditorError, "Minibuffer is not active"
      end
      s = @buffer.save_excursion {
        @buffer.beginning_of_line
        @buffer.looking_at?(/.*/)
        @buffer.match_string(0)
      }
      if s.size > 0
        Window.current = Window.echo_area
        complete_minibuffer_with_string(s)
        delete_completions_window
      end
    end
  end
end
