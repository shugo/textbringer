# frozen_string_literal: true

module Textbringer
  class ProgrammingMode < Mode
    # abstract mode
    undefine_command(:programming_mode)

    define_generic_command :indent_line
    define_generic_command :newline_and_reindent

    PROGRAMMING_MODE_MAP = Keymap.new
    PROGRAMMING_MODE_MAP.define_key("\t", :indent_line_command)
    PROGRAMMING_MODE_MAP.define_key("\n", :newline_and_reindent_command)

    def initialize(buffer)
      super(buffer)
      buffer.keymap = PROGRAMMING_MODE_MAP
    end

    def newline_and_reindent
      @buffer.insert("\n")
      indent_line_command
    end
  end
end
