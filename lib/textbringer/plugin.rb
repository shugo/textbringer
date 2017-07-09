# frozen_string_literal: true

module Textbringer
  module Plugin
    class << self
      attr_accessor :directory
    end

    @directory = File.expand_path("~/.textbringer/plugins")

    def self.load_plugins
      files = Gem.find_latest_files("textbringer_plugin.rb", false) +
        Dir.glob(File.join(directory, "*/**/textbringer_plugin.rb"))
      files.each do |file|
        begin
          load(file)
        rescue Exception => e
          show_exception(e)
        end
      end
    end
  end
end
