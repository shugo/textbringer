# frozen_string_literal: true

module Textbringer
  module Plugin
    def self.load_plugins
      files = Gem.find_files("textbringer_plugin.rb")
      files.group_by { |file|
        file.slice(/([^\/]+)-[\w.]+\/lib\/textbringer_plugin\.rb\z/, 1)
      }.map { |gem, versions|
        versions.sort_by { |version|
          v = version.slice(/[^\/]+-([\w.]+)\/lib\/textbringer_plugin\.rb\z/,
                            1)
          Gem::Version.create(v)
        }.last
      }.each do |file|
        load(file)
      end
    end
  end
end

