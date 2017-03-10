# frozen_string_literal: true

module Textbringer
  module Commands
    define_command(:describe_bindings) do
      help = Buffer.find_or_new("*Help*", undo_limit: 0)
      help.read_only_edit do
        s = format("%-16s  %s\n", "Key", "Binding")
        s << format("%-16s  %s\n", "---", "-------")
        s << "\n"
        bindings = {}
        [
          GLOBAL_MAP,
          Buffer.current.keymap,
          Controller.current.overriding_map
        ].each do |map|
          map&.each do |key_sequence, command|
            bindings[key_sequence] = command
          end
        end
        bindings.each do |key_sequence, command|
          s << format("%-16s  %s\n",
                      Keymap.key_sequence_string(key_sequence),
                      command)
        end
        help.insert(s)
        help.beginning_of_buffer
        switch_to_buffer(help)
      end
    end
  end
end
