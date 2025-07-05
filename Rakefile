require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc "Run all tests"
task :test => :spec

desc "Run linting"
task :lint => :rubocop

desc "Run tests and linting"
task :check => [:test, :lint]

desc "Start interactive console"
task :console do
  require_relative 'lib/mutation'
  require 'pry'
  Pry.start
end

desc "Run simulation"
task :simulate do
  require_relative 'lib/mutation'
  simulator = Mutation::Simulator.new
  simulator.start
end

desc "Run benchmark"
task :benchmark do
  require_relative 'lib/mutation'
  puts "Running benchmark..."
  
  start_time = Time.now
  simulator = Mutation::Simulator.new
  simulator.run_for_ticks(1000)
  end_time = Time.now
  
  puts "Benchmark completed in #{(end_time - start_time).round(2)} seconds"
  puts simulator.detailed_report
end

desc "Show version"
task :version do
  require_relative 'lib/mutation/version'
  puts "Mutation Simulator v#{Mutation::VERSION}"
end

task :default => :check 