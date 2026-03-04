module Textbringer
  class EmacsLispMode < ProgrammingMode
    self.file_name_pattern = /\A.*\.el\z/

    KEYWORDS = %w(
      defun defvar defcustom defmacro defconst defsubst defadvice
      let let* if when unless cond progn prog1 prog2
      while lambda setq quote function
      and or not
      save-excursion save-restriction save-match-data
      unwind-protect condition-case catch throw
      interactive declare
      provide require
    )

    define_syntax :comment, /;.*$/

    define_syntax :keyword, /
      \b (?: #{KEYWORDS.join("|")} ) \b
    /x

    define_syntax :string, /
      " (?: [^\\"] | \\ . )* "
    /x

    EMACS_LISP_MODE_MAP = Keymap.new
    EMACS_LISP_MODE_MAP.define_key("\C-c\C-e", :eval_elisp_buffer)

    def initialize(buffer)
      super(buffer)
      buffer.keymap = EMACS_LISP_MODE_MAP
    end

    def comment_start
      ";; "
    end

    def forward_definition
      @buffer.re_search_forward(/^\(def/)
      @buffer.beginning_of_line
    end

    def backward_definition
      @buffer.re_search_backward(/^\(def/)
    end

    def symbol_pattern
      /[A-Za-z0-9_\-]/
    end

    private

    def calculate_indentation
      @buffer.save_excursion do
        @buffer.beginning_of_line
        if @buffer.point == @buffer.point_min
          return 0
        end

        # Count unclosed parens to determine indentation
        @buffer.backward_char
        indent = 0
        depth = 0
        pos = @buffer.point
        # Scan backwards to find enclosing paren
        count = 0
        while @buffer.point > @buffer.point_min && count < 4000
          ch = @buffer.char_before
          case ch
          when ")"
            depth += 1
          when "("
            if depth > 0
              depth -= 1
            else
              # Found enclosing open paren
              indent = @buffer.current_column + 2
              break
            end
          end
          @buffer.backward_char
          count += 1
        end
        indent
      end
    end
  end
end
