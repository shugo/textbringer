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
      key = Controller.current.last_key
      Controller.current.call_last_keyboard_macro(n)
      map = Keymap.new
      map.define_key(key, :call_last_keyboard_macro)
      set_transient_map(map)
    end

    define_command(:name_last_keyboard_macro) do
      |name = read_from_minibuffer("Name for last keyboard macro: ")|
      last_keyboard_macro = Controller.current.last_keyboard_macro
      if last_keyboard_macro.nil?
        raise EditorError, "Keyboard macro not defined"
      end
      define_command(name) do |n = number_prefix_arg|
        Controller.current.execute_keyboard_macro(last_keyboard_macro, n)
      end
    end
  end
end
