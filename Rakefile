# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

ENV["KUSAMETER_COVERAGE"] = "1"
RSpec::Core::RakeTask.new(:spec)

task :lint do
  sh "bundle exec rubocop --only Lint"
  sh "bundle exec rbs validate"
  sh "bundle exec steep check"
end

task default: %i[spec lint]
