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
  system "git checkout main" or exit(1)
  system "git pull" or exit(1)
  system "git checkout -b bump_version_to_v#{version}" or exit(1)
  File.write("lib/textbringer/version.rb", <<~EOF)
    module Textbringer
      VERSION = "#{version}"
    end
  EOF
  system "git commit -a -m 'Bump version to #{version}'" or exit(1)
  system "git push" or exit(1)
  system "gh pr create --title 'Bump version to #{version}' --body ''" or exit(1)
  system "git checkout main" or exit(1)
end
