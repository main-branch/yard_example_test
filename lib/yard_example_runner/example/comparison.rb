# frozen_string_literal: true

module YardExampleRunner
  class Example < ::Minitest::Spec
    # Comparison and matcher logic for verifying example expectations
    #
    # This module is included into {Example} so that its methods have direct
    # access to Minitest assertions (+assert+, +assert_equal+, +assert_nil+,
    # +diff+) inherited from +Minitest::Spec+. It also delegates to the
    # {Evaluator} (via {Example#evaluator}) for expression evaluation.
    #
    # The module handles three verification strategies:
    #
    # 1. **Block matchers** — matchers that implement +supports_block_expectations?+
    #    (e.g. RSpec's +raise_error+, +change+, +output+). The actual expression
    #    is wrapped in a +Proc+ and passed unevaluated.
    # 2. **Value matchers** — matchers that implement +matches?+ (e.g. +eq+,
    #    +be_a+, +be_within+). The actual expression is evaluated and the
    #    resulting value is passed.
    # 3. **Bare values** — compared via {#compare_values} using error handling,
    #    +nil+ checks, and +===+ case equality.
    #
    module Comparison
      protected

      # Evaluates both the actual and expected expressions and compares their results
      #
      # The expected expression is always evaluated first via
      # {Evaluator#evaluate_with_assertion} (which captures any +StandardError+
      # as a value). The result determines which of two branches is taken:
      #
      # 1. **Matcher** ({#matcher?}) — delegates to {#assert_matcher}, which
      #    handles both block matchers (e.g. +raise_error+) and value matchers
      #    (e.g. +eq+, +be_a+, +be_within+).
      # 2. **Bare value** — +actual+ is also evaluated via
      #    {Evaluator#evaluate_with_assertion} and the pair is compared via
      #    {#compare_values}, which handles error-vs-error, single-error,
      #    +nil+, and +===+ cases.
      #
      # On failure the backtrace is decorated with the example's source location
      # via {Example#add_filepath_to_backtrace}.
      #
      # @param example [Example] the owning example, used to decorate failure backtraces
      #
      # @param expected [String] the Ruby expression representing the expected value
      #
      # @param actual [String] the Ruby expression representing the actual value
      #
      # @param bind [Class, nil] the class scope to evaluate +actual+ in; +expected+
      #   is always evaluated in a +nil+ binding (top-level context)
      #
      # @return [void]
      #
      # @raise [Minitest::Assertion] re-raises any assertion failure with the
      #   example's filepath prepended to the backtrace
      #
      # @example
      #   verify_actual(example, '42', 'answer', nil)
      #
      # @api private
      #
      def verify_actual(example, expected, actual, bind)
        expected = evaluator.evaluate_with_assertion(expected, nil)

        if matcher?(expected)
          assert_matcher(expected, actual, bind)
        else
          actual = evaluator.evaluate_with_assertion(actual, bind)
          compare_values(expected, actual)
        end
      rescue Minitest::Assertion => e
        add_filepath_to_backtrace(e, example.filepath)
        raise e
      end

      # Evaluates +actual+ and asserts a matcher against it
      #
      # When the matcher is a {#block_matcher?}, the actual expression is wrapped
      # in a +Proc+ and passed unevaluated so the matcher can invoke it (e.g.
      # +raise_error+). Otherwise the actual expression is evaluated via
      # {Evaluator#evaluate} and the resulting value is matched. If evaluation
      # raises, the error propagates — use a block matcher like +raise_error+
      # to assert on exceptions.
      #
      # @param expected [#matches?] a matcher object
      # @param actual [String] the Ruby expression representing the actual value
      # @param bind [Class, nil] the class scope for evaluation
      #
      # @return [void]
      #
      # @example
      #   assert_matcher(eq(42), 'answer', nil)
      #
      # @api private
      #
      def assert_matcher(expected, actual, bind)
        subject = if block_matcher?(expected)
                    -> { evaluator.evaluate(actual, bind) }
                  else
                    evaluator.evaluate(actual, bind)
                  end
        assert expected.matches?(subject), failure_message_for(expected)
      end

      # Compares two already-evaluated values and raises on mismatch
      #
      # Handles four cases in priority order:
      #
      # 1. **Both are errors** — compares their string representations
      #    (++"#<ClassName: message>"+++) with +assert_equal+, so mismatched error
      #    types or messages produce a readable diff.
      # 2. **Only one is an error** — raises that error directly, surfacing an
      #    unexpected exception as a test failure.
      # 3. **Expected is +nil+** — uses +assert_nil+ so Minitest's nil-specific
      #    failure message is produced.
      # 4. **Otherwise** — uses +assert+ with +===+ (case equality), which allows
      #    +expected+ to be a +Regexp+, a +Range+, a +Proc+, or any other object
      #    that implements a meaningful +===+.
      #
      # @param expected [Object] the already-evaluated expected value (or a
      #   +StandardError+ if evaluation raised)
      #
      # @param actual [Object] the already-evaluated actual value (or a
      #   +StandardError+ if evaluation raised)
      #
      # @return [void]
      #
      # @raise [Minitest::Assertion] if the values do not match under the applicable rule
      #
      # @raise [StandardError] if exactly one of the values is an error
      #
      # @example
      #   compare_values(42, 42)
      #
      # @api private
      #
      def compare_values(expected, actual)
        if both_are_errors?(expected, actual)
          assert_equal("#<#{expected.class}: #{expected}>", "#<#{actual.class}: #{actual}>")
        elsif (error = only_one_is_error?(expected, actual))
          raise error
        elsif expected.nil?
          assert_nil(actual)
        else
          assert expected === actual, diff(expected, actual) # rubocop:disable Style/CaseEquality
        end
      end

      # Returns +true+ if +obj+ implements the matcher protocol
      #
      # Checks for the presence of a +matches?+ method, which is the standard
      # interface for both RSpec matchers and +minitest-matchers+.
      #
      # @param obj [Object] the object to test
      #
      # @return [Boolean]
      #
      # @example
      #   matcher?(eq(42)) # => true
      #
      # @api private
      #
      def matcher?(obj)
        obj.respond_to?(:matches?)
      end

      # Returns +true+ if +obj+ is a block-style matcher
      #
      # A block matcher is a {#matcher?} that also responds to
      # +supports_block_expectations?+ and returns +true+ from it. RSpec's
      # +raise_error+, +change+, and +output+ matchers follow this protocol.
      #
      # @param obj [Object] the object to test
      #
      # @return [Boolean]
      #
      # @example
      #   block_matcher?(raise_error(RuntimeError)) # => true
      #
      # @api private
      #
      def block_matcher?(obj)
        matcher?(obj) &&
          obj.respond_to?(:supports_block_expectations?) &&
          obj.supports_block_expectations?
      end

      # Returns the failure message from a matcher, with legacy fallback
      #
      # Tries +failure_message+ first (RSpec 3.x / modern minitest-matchers),
      # then falls back to +failure_message_for_should+ (RSpec 2.x / older
      # minitest-matchers).
      #
      # @param a_matcher [#failure_message, #failure_message_for_should] the matcher
      #
      # @return [String, nil] the failure message, or +nil+ if neither method exists
      #
      # @example
      #   failure_message_for(eq(42))
      #
      # @api private
      #
      def failure_message_for(a_matcher)
        if a_matcher.respond_to?(:failure_message)
          a_matcher.failure_message
        elsif a_matcher.respond_to?(:failure_message_for_should)
          a_matcher.failure_message_for_should
        end
      end

      private

      # Returns +true+ if both values are +StandardError+ instances
      #
      # @param expected [Object] the expected value
      # @param actual [Object] the actual value
      #
      # @return [Boolean]
      #
      # @example
      #   both_are_errors?(RuntimeError.new, ArgumentError.new) # => true
      #
      # @api private
      #
      def both_are_errors?(expected, actual)
        expected.is_a?(StandardError) && actual.is_a?(StandardError)
      end

      # Returns the error if exactly one value is a +StandardError+, otherwise +nil+
      #
      # @param expected [Object] the expected value
      # @param actual [Object] the actual value
      #
      # @return [StandardError, nil]
      #
      # @example
      #   only_one_is_error?(RuntimeError.new, 42) # => RuntimeError
      #
      # @api private
      #
      def only_one_is_error?(expected, actual)
        if expected.is_a?(StandardError) && !actual.is_a?(StandardError)
          expected
        elsif !expected.is_a?(StandardError) && actual.is_a?(StandardError)
          actual
        end
      end
    end
  end
end
