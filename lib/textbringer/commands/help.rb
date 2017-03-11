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

    define_command(:describe_bindings,
                   doc: "Display the key bindings.") do
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

    def command_help(cmd)
      s = format("%s:%d\n", *cmd.block.source_location)
      s << "-" * (Window.columns - 2) + "\n"
      s << "#{cmd.name}"
      if !cmd.block.parameters.empty?
        s << "("
        s << cmd.block.parameters.map { |_, param| param }.join(", ")
        s << ")"
      end
      s << "\n\n"
      s << "-" * (Window.columns - 2) + "\n\n"
      s << cmd.doc
      s << "\n"
      s
    end

    define_command(:describe_command,
                   doc: "Display the documentation of the command.") do
      |name = read_command_name("Describe command: ")|
      cmd = Commands[name]
      if cmd.nil?
        raise EditorError, "No such command: #{name}"
      end
      show_help do |help|
        help.insert(command_help(cmd))
      end
    end

    define_command(:describe_key,
                   doc: <<~EOD) do
        Display the documentation of the command invoked by key.
      EOD
      |key = read_key_sequence("Describe key: ")|
      name = Buffer.current.keymap&.lookup(key) ||
        GLOBAL_MAP.lookup(key)
      cmd = Commands[name]
      show_help do |help|
        s = Keymap.key_sequence_string(key)
        s << " runs the command #{name}, which is defined in\n"
        s << command_help(cmd)
        help.insert(s)
      end
    end
  end
end
