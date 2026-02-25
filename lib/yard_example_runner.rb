# frozen_string_literal: true

require 'yard'
require 'minitest'
require 'minitest/spec'

require_relative 'yard/cli/run_examples'
require_relative 'yard_example_runner/example'
require_relative 'yard_example_runner/expectation'
require_relative 'yard_example_runner/version'

# Provides configuration and hooks for running YARD @example tags as tests.
#
# @api public
#
module YardExampleRunner
  # Configures YardExampleRunner
  #
  # @example
  #   YardExampleRunner.configure do |runner|
  #     runner.before { @value = 1 }
  #     runner.after { puts 'done' }
  #   end
  #
  # @yield [self] gives the module itself to the block for configuration
  #
  # @return [void]
  #
  # @api public
  #
  def self.configure
    yield self
  end

  # Registers a block to be called before each example, or before a specific test
  #
  # The block is evaluated in the same context as the example.
  #
  # @example Register a global before hook
  #   YardExampleRunner.before { @value = 1 }
  #
  # @example Register a hook for a specific test
  #   YardExampleRunner.before('#my_method') { @value = 42 }
  #
  # @param test [String, nil] the test name to match, or +nil+ for all tests
  #
  # @param blk [Proc] the block to call before the matched example(s)
  #
  # @return [void]
  #
  # @api public
  #
  def self.before(test = nil, &blk)
    hooks[:before] << { test: test, block: blk }
  end

  # Registers a block to be called after each example, or after a specific test
  #
  # The block is evaluated in the same context as the example.
  #
  # @example Register a global after hook
  #   YardExampleRunner.after { puts 'done' }
  #
  # @example Register a hook for a specific test
  #   YardExampleRunner.after('#my_method') { puts 'my_method done' }
  #
  # @param test [String, nil] the test name to match, or +nil+ for all tests
  #
  # @param blk [Proc] the block to call after the matched example(s)
  #
  # @return [void]
  #
  # @api public
  #
  def self.after(test = nil, &blk)
    hooks[:after] << { test: test, block: blk }
  end

  # Registers a block to be called after all examples have run
  #
  # The block is evaluated in a different context from the examples. Delegates
  # to +Minitest.after_run+.
  #
  # @example
  #   YardExampleRunner.after_run { puts 'All examples finished' }
  #
  # @return [void]
  #
  # @api public
  #
  def self.after_run(&)
    Minitest.after_run(&)
  end

  # Registers a test definition to be skipped
  #
  # @example
  #   YardExampleRunner.skip '#my_method'
  #
  # @param test [String] the test name or definition path to skip
  #
  # @return [void]
  #
  # @api public
  #
  def self.skip(test)
    skips << test
  end

  # Returns the array of test definitions registered to be skipped
  #
  # @return [Array<String>] the registered skip patterns
  #
  # @api private
  #
  def self.skips
    @skips ||= []
  end

  # Returns the hash of registered before/after hooks
  #
  # @return [Hash{Symbol => Array<Hash>}] the registered hooks grouped by type
  #
  # @api private
  #
  def self.hooks
    @hooks ||= {}.tap do |hash|
      hash[:before] = []
      hash[:after] = []
    end
  end
end

YARD::CLI::CommandParser.commands[:'run-examples'] = YARD::CLI::RunExamples
