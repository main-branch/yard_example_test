# frozen_string_literal: true

require 'rake'
require 'rake/tasklib'

module YardExampleTest
  # Rake task for running YARD @example tags as tests.
  #
  # @example Define the task with defaults
  #   YardExampleTest::RakeTask.new
  #
  # @example Define the task with custom options
  #   YardExampleTest::RakeTask.new do |task|
  #     task.test_examples_opts = %w[-v]
  #     task.pattern = 'app/**/*.rb'
  #   end
  #
  # @api public
  #
  class RakeTask < ::Rake::TaskLib
    # The name of the Rake task
    #
    # @example
    #   task = YardExampleTest::RakeTask.new
    #   task.name #=> 'yard:test-examples'
    #
    # @return [String] the task name
    #
    attr_accessor :name

    # Options passed to the +yard test-examples+ command
    #
    # @example
    #   task = YardExampleTest::RakeTask.new
    #   task.test_examples_opts = %w[-v]
    #   task.test_examples_opts #=> ['-v']
    #
    # @return [Array<String>] the command-line options
    #
    attr_accessor :test_examples_opts

    # Glob pattern for files to pass to +yard test-examples+
    #
    # @example
    #   task = YardExampleTest::RakeTask.new
    #   task.pattern = 'app/**/*.rb'
    #   task.pattern #=> 'app/**/*.rb'
    #
    # @return [String] the glob pattern, or an empty string to use the default
    #
    attr_accessor :pattern

    # Creates and registers the Rake task
    #
    # @example
    #   YardExampleTest::RakeTask.new do |task|
    #     task.test_examples_opts = %w[-v]
    #     task.pattern = 'app/**/*.rb'
    #   end
    #
    # @param name [String] the Rake task name
    #
    # @yield [self] gives the task instance to the block for configuration
    #
    # @return [void]
    #
    def initialize(name = 'yard:test-examples')
      super()
      @name = name
      @test_examples_opts = []
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
        args = test_examples_opts + (pattern.empty? ? [] : [pattern])
        abort unless system('yard', 'test-examples', *args)
      end
    end
  end
end
