# frozen_string_literal: true

module YardExampleRunner
  # @!parse
  #   # Represents a single expected outcome parsed from a YARD +@example+ tag
  #   #
  #   # Each instance holds the Ruby expression to evaluate (+actual+) and the
  #   # string representation of the value it should return (+expected+). When
  #   # +expected+ is +nil+, the expression is evaluated for side-effects only and
  #   # no assertion is made against its return value.
  #   #
  #   # @!attribute actual [r]
  #   #   @return [String] the Ruby expression to evaluate
  #   #
  #   # @!attribute expected [r]
  #   #   @return [String, nil] the expected return value, or +nil+ if no
  #   #     assertion should be made
  #   #
  #   # @api public
  #   #
  #   class Expectation < Data
  Expectation = Data.define(:actual, :expected)
end
