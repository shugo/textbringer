require "open3"
require "io/wait"

module Textbringer
  class Command < Data.define(:name, :block, :doc, :source_location_proc)
    def source_location
      source_location_proc&.call || block.source_location
    end
  end

  module Commands
    include Utils

    @command_table = {}

    def self.list
      @command_table.keys
    end

    def self.command_table
      @command_table
    end

    def self.[](name)
      @command_table[name.intern]
    end

    def define_command(name, doc: "No documentation", source_location_proc: nil, &block)
      name = name.intern
      Commands.send(:define_method, name, &block)
      Commands.send(:module_function, name)
      Commands.command_table[name] = Command.new(name, block, doc, source_location_proc)
      name
    end
    module_function :define_command

    def undefine_command(name)
      name = name.intern
      if Commands.command_table.key?(name)
        Commands.send(:undef_method, name)
        Commands.command_table.delete(name)
      end
    end
    module_function :undefine_command
  end
end
