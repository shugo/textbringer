# frozen_string_literal: true

module Textbringer
  module Commands
    define_command(:start_keyboard_macro) do
      message("Recording keyboard macro...")
      Controller.current.start_keyboard_macro
    end

    define_command(:end_keyboard_macro) do
      Controller.current.end_keyboard_macro
      message("Keyboard macro defined")
    end

    define_command(:call_last_keyboard_macro) do |n = number_prefix_arg|
      Controller.current.call_last_keyboard_macro(n)
    end
  end
end
