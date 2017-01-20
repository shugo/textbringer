# frozen_string_literal: true

module Textbringer
  class ProgrammingMode < Mode
    # abstract mode
    undefine_command(:programming_mode)

    define_generic_command :indent_line

    PROGRAMMING_MODE_MAP = Keymap.new
    PROGRAMMING_MODE_MAP.define_key("\t", :indent_line_command)

    def initialize(buffer)
      super(buffer)
      buffer.keymap = PROGRAMMING_MODE_MAP
    end
  end
end
