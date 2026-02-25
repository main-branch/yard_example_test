# frozen_string_literal: true

require 'rake'
require 'rake/tasklib'

module YardExampleRunner
  # Rake task for running YARD @example tags as tests.
  #
  # @example Define the task with defaults
  #   YardExampleRunner::RakeTask.new
  #
  # @example Define the task with custom options
  #   YardExampleRunner::RakeTask.new do |task|
  #     task.run_examples_opts = %w[-v]
  #     task.pattern = 'app/**/*.rb'
  #   end
  #
  # @api public
  #
  class RakeTask < ::Rake::TaskLib
    # The name of the Rake task
    #
    # @example
    #   task = YardExampleRunner::RakeTask.new
    #   task.name #=> 'yard:run-examples'
    #
    # @return [String] the task name
    #
    attr_accessor :name

    # Options passed to the +yard run-examples+ command
    #
    # @example
    #   task = YardExampleRunner::RakeTask.new
    #   task.run_examples_opts = %w[-v]
    #   task.run_examples_opts #=> ['-v']
    #
    # @return [Array<String>] the command-line options
    #
    attr_accessor :run_examples_opts

    # Glob pattern for files to pass to +yard run-examples+
    #
    # @example
    #   task = YardExampleRunner::RakeTask.new
    #   task.pattern = 'app/**/*.rb'
    #   task.pattern #=> 'app/**/*.rb'
    #
    # @return [String] the glob pattern, or an empty string to use the default
    #
    attr_accessor :pattern

    # Creates and registers the Rake task
    #
    # @example
    #   YardExampleRunner::RakeTask.new do |task|
    #     task.run_examples_opts = %w[-v]
    #     task.pattern = 'app/**/*.rb'
    #   end
    #
    # @param name [String] the Rake task name
    #
    # @yield [self] gives the task instance to the block for configuration
    #
    # @return [void]
    #
    def initialize(name = 'yard:run-examples')
      super()
      @name = name
      @run_examples_opts = []
      @pattern = ''
      yield self if block_given?
      define
    end

    protected

    # Defines the Rake task
    #
    # @return [void]
    #
    # @api private
    #
    def define
      desc 'Run YARD @example tags as tests'
      task(name) do
        args = run_examples_opts + (pattern.empty? ? [] : [pattern])
        abort unless system('yard', 'run-examples', *args)
      end
    end
  end
end
