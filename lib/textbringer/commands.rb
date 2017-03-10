# frozen_string_literal: true

require "open3"
require "io/wait"

module Textbringer
  module Commands
    include Utils

    @command_list = []

    def self.list
      @command_list
    end

    def define_command(name, &block)
      name = name.intern
      Commands.send(:define_method, name, &block)
      Commands.list << name if !Commands.list.include?(name)
      name
    end
    module_function :define_command

    def undefine_command(name)
      name = name.intern
      if Commands.list.include?(name)
        Commands.send(:undef_method, name)
        Commands.list.delete(name)
      end
    end
    module_function :undefine_command
  end
end
