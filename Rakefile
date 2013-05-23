require "rake/testtask"


Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  files = FileList["test/**/*_test.rb"]
  test.test_files = files
  test.verbose = true
  test.warning = false # true # Warnings from third-party libraries!...
end

task :set_coverage_env do
  ENV["COVERAGE"] = "true"
end

desc "Run Simplecov (only works on 1.9)"
task :coverage => [:set_coverage_env, :test]


task :default => :test

# End of file