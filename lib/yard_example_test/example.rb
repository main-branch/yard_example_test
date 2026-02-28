# frozen_string_literal: true

require_relative 'example/constant_sandbox'
require_relative 'example/evaluator'
require_relative 'example/comparison'

module YardExampleTest
  # Represents a YARD +@example+ tag as a runnable +Minitest::Spec+
  #
  # Each instance is populated from a single +@example+ tag by
  # {YARD::CLI::TestExamples#build_spec} and holds everything needed to
  # generate and execute a test:
  #
  # - {#definition} — the YARD path of the documented object
  #   (e.g. +"MyClass#my_method"+), used as the spec description
  #
  # - {#filepath} — the source location of the documented object
  #   (e.g. +"lib/my_class.rb:10"+), prepended to failure backtraces
  #
  # - {#expectations} — the list of {Expectation} objects parsed from the
  #   example body, each pairing a Ruby expression to evaluate with an
  #   optional expected return value
  #
  # Calling {#generate} dynamically defines and registers an anonymous
  # +Minitest::Spec+ subclass that wraps the expectations in a single +it+
  # block. The registered spec is then picked up by +Minitest.autorun+ when
  # the process exits.
  #
  # Each expectation is evaluated inside a binding scoped to the owning
  # object's class (if one can be resolved), so instance methods and
  # constants are available without qualification, mirroring how the code
  # appears in the source documentation.
  #
  # Evaluation is delegated to an {Evaluator} (binding management and
  # +eval+), constant isolation is handled by {ConstantSandbox}, and
  # assertion / matcher logic lives in the {Comparison} module.
  #
  # @see YARD::CLI::TestExamples
  #
  # @see Expectation
  #
  # @see Evaluator
  #
  # @see ConstantSandbox
  #
  # @see Comparison
  #
  # @api public
  #
  class Example < ::Minitest::Spec
    include Comparison

    # The YARD namespace path of the documented object (e.g. +Foo#bar+)
    #
    # @example
    #   example.definition #=> 'Foo#bar'
    #
    # @return [String] namespace path of example
    #
    # @api public
    attr_accessor :definition

    # The source location of the documented object (e.g. +app/app.rb:10+)
    #
    # @example
    #   example.filepath #=> 'app/app.rb:10'
    #
    # @return [String] filepath to definition
    #
    # @api public
    attr_accessor :filepath

    # The list of expectations parsed from the example body
    #
    # @example
    #   example.expectations #=> []
    #
    # @return [Array<YardExampleTest::Expectation>] expectations to be verified
    #
    # @api public
    attr_accessor :expectations

    # Dynamically defines and registers a +Minitest::Spec+ for this example
    #
    # Creates an anonymous subclass of this class and evaluates a +describe+/+it+
    # block inside it. The steps are:
    #
    # 1. Calls +load_helpers+ to require any +example_test_helper+ files found in
    #    +.+, +support/+, +spec/+, or +test/+.
    # 2. Skips silently if {YardExampleTest.skips} contains a substring that
    #    matches {#definition}.
    # 3. Opens a +describe+ block keyed on {#definition}, which becomes the spec
    #    group name reported by Minitest.
    # 4. Registers any matching +before+/+after+ hooks via +register_hooks+. These
    #    are registered by the user with {YardExampleTest.before} and
    #    {YardExampleTest.after}.
    # 5. Opens an +it+ block keyed on +name+ (the +@example+ tag title) that calls
    #    +run_expectations+ to evaluate every {Expectation} in {#expectations}.
    #
    # The anonymous class and its specs are registered with Minitest's internal list
    # by the +describe+ call. They will be executed when +Minitest.autorun+'s
    # +at_exit+ hook fires.
    #
    # @example
    #   example.generate
    #
    # @return [void]
    #
    def generate
      self.class.send(:load_helpers)
      return if skipped?

      this = self
      Class.new(this.class).class_eval do
        describe this.definition do
          register_hooks(example_name_for(this), YardExampleTest.hooks, this)
          it(this.name) { run_expectations(this) }
        end
      end
    end

    protected

    # Returns +true+ if this example's {#definition} matches any skip pattern
    #
    # Iterates over {YardExampleTest.skips} and returns +true+ as soon as a
    # pattern is found that is a substring of {#definition}. Used by {#generate}
    # to bail out before registering any +Minitest::Spec+ subclass.
    #
    # @example
    #   example.skipped? #=> false
    #
    # @return [Boolean] +true+ if the example should be skipped, +false+ otherwise
    #
    # @api private
    #
    def skipped?
      YardExampleTest.skips.any? { |skip| definition.include?(skip) }
    end

    # Evaluates every {Expectation} in the given example
    #
    # Delegates constant isolation to {ConstantSandbox}, which snapshots
    # the current constants on +Object+ and the resolved scope, yields the
    # scope for evaluation, then removes any constants that were introduced
    # during evaluation.
    #
    # @param example [Example] the example whose {Example#expectations} are to be run
    #
    # @example
    #   run_expectations(example)
    #
    # @return [void]
    #
    # @api private
    #
    def run_expectations(example)
      ConstantSandbox.new(example.definition).isolate do |scope|
        example.expectations.each { |expectation| run_expectation(example, expectation, scope) }
      end
    end

    # Evaluates a single {Expectation} within the given scope
    #
    # If the expectation has no expected value ({Expectation#expected} is +nil+),
    # the actual expression is evaluated for its side-effects only via
    # {#evaluate_actual}. Otherwise the actual and expected expressions are both
    # evaluated and compared via {Comparison#verify_actual}.
    #
    # @param example [Example] the owning example, used for backtrace decoration
    #
    # @param expectation [Expectation] the expectation to evaluate
    #
    # @param scope [Class, nil] the class scope to evaluate expressions in, or
    #   +nil+ to evaluate in the default binding
    #
    # @example
    #   run_expectation(example, expectation, MyClass)
    #
    # @return [void]
    #
    # @api private
    #
    def run_expectation(example, expectation, scope)
      if expectation.expected.nil?
        evaluate_actual(example, expectation.actual, scope)
      else
        verify_actual(example, expectation.expected, expectation.actual, scope)
      end
    end

    # Evaluates the actual expression for side-effects only
    #
    # Delegates to {Evaluator#evaluate} and re-raises any +StandardError+ after
    # prepending the example's source location to the backtrace via
    # {#add_filepath_to_backtrace}, so that failure output points to the
    # documented source rather than this file.
    #
    # @param example [Example] the owning example, used to decorate error backtraces
    #
    # @param actual [String] the Ruby expression to evaluate
    #
    # @param bind [Class, nil] the class scope to evaluate the expression in, or
    #   +nil+ to use the default binding
    #
    # @example
    #   evaluate_actual(example, 'foo(1)', MyClass)
    #
    # @return [void]
    #
    # @raise [StandardError] re-raises any error raised during evaluation, with the
    #   example's filepath prepended to the backtrace
    #
    # @api private
    #
    def evaluate_actual(example, actual, bind)
      evaluator.evaluate(actual, bind)
    rescue StandardError => e
      add_filepath_to_backtrace(e, example.filepath)
      raise e
    end

    # Returns the lazily-initialized {Evaluator} for this spec instance
    #
    # The evaluator is created with a fallback binding (whose +self+ is this
    # spec instance, so that methods included on {Example} — such as
    # +RSpec::Matchers+ — are accessible in evaluated code) and a snapshot of
    # the spec instance's instance variables (set by +before+ hooks).
    #
    # @example
    #   evaluator.evaluate('1 + 1', nil)
    #
    # @return [Evaluator]
    #
    # @api private
    #
    def evaluator
      @evaluator ||= Evaluator.new(
        fallback_binding: create_fallback_binding,
        instance_variables: instance_variable_hash
      )
    end

    # Prepends the example's filepath to an exception's backtrace
    #
    # @param exception [Exception] the exception to decorate
    #
    # @param filepath [String] the source location to prepend
    #
    # @example
    #   add_filepath_to_backtrace(exception, 'app/app.rb:10')
    #
    # @return [void]
    #
    # @api private
    #
    def add_filepath_to_backtrace(exception, filepath)
      exception.set_backtrace([filepath] + exception.backtrace)
    end

    private

    # Returns a binding whose +self+ is this spec instance
    #
    # Because {Example} includes any modules the user adds (e.g.
    # +RSpec::Matchers+), the returned binding automatically exposes those
    # methods to code evaluated via the {Evaluator}'s fallback path.
    #
    # @example
    #   create_fallback_binding
    #
    # @return [Binding]
    #
    # @api private
    #
    def create_fallback_binding
      binding
    end

    # Snapshots instance variables as a +Hash+
    #
    # Returns a hash mapping instance variable names to their current values
    # on this spec instance. The {Evaluator} uses this snapshot to transplant
    # hook-set state into class-scoped bindings.
    #
    # @example
    #   instance_variable_hash #=> { :@foo => 1 }
    #
    # @return [Hash{Symbol => Object}]
    #
    # @api private
    #
    def instance_variable_hash
      instance_variables.to_h do |ivar|
        [ivar, instance_variable_get(ivar)]
      end
    end

    class << self
      protected

      # Requires any +example_test_helper+ files found in known directories
      #
      # @example
      #   load_helpers
      #
      # @return [void]
      #
      # @api private
      #
      def load_helpers
        %w[. support spec test].each do |dir|
          require "#{dir}/example_test_helper" if File.exist?("#{dir}/example_test_helper.rb")
        end
      end

      # Returns the full example name including an optional title suffix
      #
      # @param example [Example] the example to build a name for
      #
      # @example
      #   example_name_for(example) #=> 'Foo#bar'
      #
      # @return [String] the example name
      #
      # @api private
      #
      def example_name_for(example)
        return example.definition if example.name.empty?

        "#{example.definition}@#{example.name}"
      end

      # Registers matching before/after hooks on the current spec context
      #
      # @param example_name [String] the name of the example
      #
      # @param all_hooks [Hash{Symbol => Array<Hash>}] hooks grouped by type
      #
      # @param example [Example] the example being registered
      #
      # @example
      #   register_hooks('Foo#bar', YardExampleTest.hooks, example)
      #
      # @return [void]
      #
      # @api private
      #
      def register_hooks(example_name, all_hooks, example)
        all_hooks.each do |type, hooks|
          global_hooks = hooks.reject { |hook| hook[:test] }
          test_hooks   = hooks.select { |hook| hook[:test] && example_name.include?(hook[:test]) }
          __send__(type) do
            (global_hooks + test_hooks).each { |hook| instance_exec(example, &hook[:block]) }
          end
        end
      end
    end
  end
end
