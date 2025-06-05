require "bundler/gem_tasks"
require "rake/testtask"
task :default => :test

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/test_*.rb"]
  t.verbose = true
  t.warning = true
end

task :bump do
  require_relative "lib/textbringer/version"
  version = Textbringer::VERSION.to_i + 1
  tag_name = "v#{version}"
  puts "Bump version to #{version}"
  sh "git checkout main"
  sh "git pull"
  File.write("lib/textbringer/version.rb", <<~EOF)
    module Textbringer
      VERSION = "#{version}"
    end
  EOF
  sh "git commit -a -m 'Bump version to #{version}'"
  sh "git push"
  sh "git tag #{tag_name}"
  sh "git push origin #{tag_name}"
end
