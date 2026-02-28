# frozen_string_literal: true

module YardExampleTest
  # @!parse
  #   # Represents a single expected outcome parsed from a YARD +@example+ tag
  #   #
  #   # @api public
  #   #
  #   # Each instance holds the Ruby expression to evaluate (+actual+) and the
  #   # string representation of the value it should return (+expected+). When
  #   # +expected+ is +nil+, the expression is evaluated for side-effects only and
  #   # no assertion is made against its return value.
  #   #
  #   # @!attribute actual [r] the Ruby expression to evaluate
  #   #   @example
  #   #     blah
  #   #   @return [String]
  #   #   @api public
  #   #
  #   # @!attribute expected [r] the expected value, or nil if no assertion should be made
  #   #   @example
  #   #     blah
  #   #   @return [String, nil]
  #   #   @api public
  #   #
  #   class Expectation < Data; end
  #
  Expectation = Data.define(:actual, :expected)
end
