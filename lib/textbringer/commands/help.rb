# frozen_string_literal: true

module Textbringer
  module Commands
    def show_help
      help = Buffer.find_or_new("*Help*", undo_limit: 0)
      help.read_only_edit do
        help.clear
        yield(help)
        help.beginning_of_buffer
        switch_to_buffer(help)
      end
    end

    define_command(:describe_bindings) do
      show_help do |help|
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
      end
    end

    define_command(:describe_command) do
      |name = read_command_name("Describe command: ")|
      cmd = Commands[name]
      if cmd.nil?
        raise EditorError, "No such command: #{name}"
      end
      show_help do |help|
        s = format("%s:%d\n", *cmd.block.source_location)
        s << "\n"
        s << "#{cmd.name}"
        if !cmd.block.parameters.empty?
          s << "("
          s << cmd.block.parameters.map { |_, param| param }.join(", ")
          s << ")"
        end
        s << "\n\n"
        s << cmd.doc
        s << "\n"
        help.insert(s)
      end
    end
  end
end
