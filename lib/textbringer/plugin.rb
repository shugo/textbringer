# frozen_string_literal: true

require "rbconfig"

module Textbringer
  module Plugin
    def self.load_plugins
      files = Gem.find_files("textbringer_plugin.rb")
      files.each do |file|
        load(file)
      end
    end
  end
end

