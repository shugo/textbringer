module Textbringer
  module Commands
    HELP_RING = Ring.new

    def push_help_command(cmd)
      if HELP_RING.empty? || HELP_RING.current != cmd
        HELP_RING.push(cmd)
      end
    end
    private :push_help_command

    def show_help
      help = Buffer.find_or_new("*Help*", undo_limit: 0)
      help.read_only_edit do
        help.clear
        yield(help)
        help.beginning_of_buffer
        switch_to_buffer(help)
        help_mode
      end
    end
    private :show_help

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
          s << format("%-16s  [%s]\n",
                      Keymap.key_sequence_string(key_sequence),
                      command)
        end
        help.insert(s)
      end
      push_help_command([:describe_bindings])
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
      push_help_command([:describe_command, name])
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
      push_help_command([:describe_key, key])
    end

    define_command(:help_go_back, doc: "Go back to the previous help.") do
      if !HELP_RING.empty?
        HELP_RING.rotate(1)
        cmd, *args = HELP_RING.current
        send(cmd, *args)
      end
    end

    define_command(:help_go_forward, doc: "Go back to the next help.") do
      if !HELP_RING.empty?
        HELP_RING.rotate(-1)
        cmd, *args = HELP_RING.current
        send(cmd, *args)
      end
    end
  end
end
