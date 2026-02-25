# frozen_string_literal: true

# YARD documentation for this project can NOT be built with JRuby or TruffleRuby.
# This project uses the redcarpet gem which can not be installed on JRuby.
#
unless RUBY_PLATFORM == 'java' || RUBY_ENGINE == 'truffleruby'
  # yard:build

  require 'yard'

  YARD::Rake::YardocTask.new('yard:build') do |t|
    t.files = %w[lib/**/*.rb]
    t.stats_options = ['--list-undoc']
  end

  CLEAN << '.yardoc'
  CLEAN << 'doc'

  # yard:audit

  desc 'Run yardstick to show missing YARD doc elements'
  task :'yard:audit' do
    sh "yardstick 'lib/**/*.rb'"
  end

  # yard:coverage

  require 'yardstick/rake/verify'

  Yardstick::Rake::Verify.new(:'yard:coverage') do |verify|
    verify.threshold = 100
    verify.require_exact_threshold = false
  end

  # yard

  desc 'Run YARD documentation tasks (build, coverage)'
  task yard: %i[yard:build yard:audit yard:coverage]
end
