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
  puts "Bump version to #{version}"
  sh "git checkout main"
  sh "git pull"
  sh "git checkout -b bump_version_to_v#{version}"
  File.write("lib/textbringer/version.rb", <<~EOF)
    module Textbringer
      VERSION = "#{version}"
    end
  EOF
  sh "git commit -a -m 'Bump version to #{version}'"
  sh "git push"
  sh "gh pr create --title 'Bump version to #{version}' --body ''"
  sh "git checkout main"
end
