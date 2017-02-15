# frozen_string_literal: true

require "open3"
require "io/wait"

module Textbringer
  module Commands
    include Utils

    @@command_list = []

    def self.list
      @@command_list
    end

    def define_command(name, &block)
      Commands.send(:define_method, name, &block)
      @@command_list << name if !@@command_list.include?(name)
      name
    end
    module_function :define_command

    def undefine_command(name)
      if @@command_list.include?(name)
        Commands.send(:undef_method, name)
        @@command_list.delete(name)
      end
    end
    module_function :undefine_command
  end
end
