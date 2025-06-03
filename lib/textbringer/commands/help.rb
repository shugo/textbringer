$".push("readline.rb")
require "rdoc/ri/driver"

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
        help.apply_mode(HelpMode)
      end
      if Window.list.size == 1
        split_window
      end
      windows = Window.list
      i = (windows.index(Window.current) + 1) % windows.size
      windows[i].buffer = help
    end
    private :show_help

    def keymap_bindings(keymap)
      s = format("%-16s  %s\n", "Key", "Binding")
      s << format("%-16s  %s\n", "---", "-------")
      s << "\n"
      keymap.each do |key_sequence, command|
        if command != :self_insert
          s << format("%-16s  [%s]\n",
                      Keymap.key_sequence_string(key_sequence),
                      command)
        end
      end
      s
    end

    define_command(:describe_bindings,
                   doc: "Display the key bindings.") do
      show_help do |help|
        s = +""
        if Controller.current.overriding_map
          s << "Overriding Bindings:\n"
          s << keymap_bindings(Controller.current.overriding_map)
          s << "\n"
        end
        if Buffer.current.keymap
          s << "Current Buffer Bindings:\n"
          s << keymap_bindings(Buffer.current.keymap)
          s << "\n"
        end
        s << "Global Bindings:\n"
        s << keymap_bindings(GLOBAL_MAP)
        help.insert(s)
      end
      push_help_command([:describe_bindings])
    end

    def command_help(cmd)
      file, line = *cmd.block.source_location
      s = format("%s:%d\n", file, line)
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

    define_command(:describe_class,
                   doc: "Display the documentation of the class.") do
      |name = read_expression("Describe class: ")|
      show_help do |help|
        old_stdout = $stdout
        $stdout = StringIO.new
        begin
          rdoc = RDoc::RI::Driver.new(use_stdout: true,
                                      formatter: RDoc::Markup::ToRdoc,
                                      interactive: false)
          rdoc.display_class(name)
          help.insert($stdout.string)
        ensure
          $stdout = old_stdout
        end
      end
      push_help_command([:describe_class, name])
    end

    define_command(:describe_method,
                   doc: "Display the documentation of the method.") do
      |name = read_expression("Describe method: ")|
      show_help do |help|
        old_stdout = $stdout
        $stdout = StringIO.new
        begin
          rdoc = RDoc::RI::Driver.new(use_stdout: true,
                                      formatter: RDoc::Markup::ToRdoc,
                                      interactive: false)
          rdoc.display_method(name)
          help.insert($stdout.string)
        ensure
          $stdout = old_stdout
        end
      end
      push_help_command([:describe_method, name])
    end

    define_command(:describe_char,
                   doc: "Describe the char after point") do
      require "unicode/name"
      require "unicode/blocks"
      require "unicode/scripts"
      require "unicode/categories"
      require "unicode/types"

      show_help do |help|
        buffer = Buffer.current
        c = buffer.char_after
        if c.nil?
          raise "No character follows specified position"
        end
        percent = (100.0 * buffer.point / buffer.bytesize).to_i
        char = /[\0-\x20\x7f]/.match?(c) ? Keymap.key_name(c) : c
        codepoint = "U+%04X" % c.ord
        name = Unicode::Name.readable(c)
        script = Unicode::Scripts.script(c)
        category = Unicode::Categories.category(c)
        category_long = Unicode::Categories.category(c, format: :long)
        block = Unicode::Blocks.block(c)
        type = Unicode::Types.type(c)
        help.insert(<<EOF)
 position: #{buffer.point} of #{buffer.bytesize} (#{percent}%), column: #{buffer.current_column}
character: #{char}
codepoint: #{codepoint}
     name: #{name}
    block: #{block}
   script: #{script}
 category: #{category} (#{category_long})
     type: #{type}
EOF
      end
      push_help_command([:describe_char])
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
