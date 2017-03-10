# frozen_string_literal: true

module Textbringer
  module Commands
    KEYBOARD_MACROS = {}

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

    def execute_keyboard_macro(macro, n = 1)
      Controller.current.execute_keyboard_macro(macro, n)
    end

    define_command(:name_last_keyboard_macro) do
      |name = read_from_minibuffer("Name for last keyboard macro: ")|
      last_keyboard_macro = Controller.current.last_keyboard_macro
      if last_keyboard_macro.nil?
        raise EditorError, "Keyboard macro not defined"
      end
      KEYBOARD_MACROS[name] = last_keyboard_macro
      define_command(name) do |n = number_prefix_arg|
        execute_keyboard_macro(last_keyboard_macro, n)
      end
    end

    def read_keyboard_macro(prompt)
      macros = KEYBOARD_MACROS.keys.map(&:to_s)
      f = ->(s) { complete_for_minibuffer(s, macros) }
      read_from_minibuffer(prompt, completion_proc: f)
    end

    module SymbolDump
      refine Symbol do
        def dump
          ":" + to_s.dump
        end
      end
    end

    using SymbolDump

    define_command(:insert_keyboard_macro) do
      |name = read_keyboard_macro("Insert keyboard macro: ")|
      macro = KEYBOARD_MACROS[name]
      if macro.nil?
        raise EditorError, "No such macro: #{name}"
      end
      macro_literal = "[" + macro.map(&:dump).join(",") + "]"
      insert(<<~EOF)
        define_command(:#{name}) do |n = number_prefix_arg|
          execute_keyboard_macro(#{macro_literal}, n)
        end
      EOF
    end
  end
end
