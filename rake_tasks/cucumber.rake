# frozen_string_literal: true

require 'cucumber/rake/task'

Cucumber::Rake::Task.new do |task|
  task.cucumber_opts = %w[-f progress features --publish-quiet]
end

CLEAN << 'tmp'
