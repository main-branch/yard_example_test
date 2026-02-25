# frozen_string_literal: true

module YardExampleRunner
  class Example < ::Minitest::Spec
    # Manages binding creation and code evaluation for example expressions
    #
    # Each {Evaluator} is constructed with a fallback binding (whose +self+ is
    # the +Minitest::Spec+ instance, providing access to any methods included
    # on {Example} such as +RSpec::Matchers+) and a snapshot of instance
    # variables from the spec instance (set by +before+ hooks). These are used
    # to build per-scope evaluation contexts that mirror the documented class's
    # namespace.
    #
    # @see Example
    #
    class Evaluator
      # Creates a new evaluator
      #
      # @param fallback_binding [Binding] a binding whose +self+ is the spec
      #   instance, used when the expression is not scoped to a specific class
      #
      # @param instance_variables [Hash{Symbol => Object}] a snapshot of instance
      #   variable names to values from the spec instance, transplanted into
      #   class-scoped bindings so that hook-set state is accessible
      #
      # @example
      #   Evaluator.new(fallback_binding: binding, instance_variables: {})
      #
      # @api private
      #
      def initialize(fallback_binding:, instance_variables:)
        @fallback_binding = fallback_binding
        @instance_variables = instance_variables
      end

      # Evaluates a Ruby code string in the given scope
      #
      # @param code [String] the Ruby expression to evaluate
      # @param bind [Class, nil] the class scope to evaluate in, or +nil+ for
      #   the default (fallback) binding
      #
      # @return [Object] the result of evaluating +code+
      #
      # @raise [StandardError] any error raised during evaluation propagates
      #
      # @example
      #   evaluator.evaluate('1 + 1', nil) # => 2
      #
      # @api private
      #
      def evaluate(code, bind)
        context(bind).eval(code)
      end

      # Evaluates a Ruby code string, capturing any +StandardError+ as a value
      #
      # If evaluation raises a +StandardError+, the error itself is returned
      # instead of propagating. This allows callers to compare raised errors
      # against expected error values.
      #
      # @param code [String] the Ruby expression to evaluate
      # @param bind [Class, nil] the class scope to evaluate in
      #
      # @return [Object, StandardError] the result of evaluation, or the error
      #
      # @example
      #   evaluator.evaluate_with_assertion('raise "oops"', nil) # => RuntimeError
      #
      # @api private
      #
      def evaluate_with_assertion(code, bind)
        evaluate(code, bind)
      rescue StandardError => e
        e
      end

      private

      # Returns or creates the cached evaluation context for the given scope
      #
      # @param bind [Class, nil] the class scope
      #
      # @return [Binding] a binding suitable for evaluating code in +bind+
      #
      # @example
      #   context(MyClass) # => Binding
      #
      # @api private
      #
      def context(bind)
        @contexts ||= {}.compare_by_identity
        @contexts[bind] ||= build_context(bind)
      end

      # Builds an evaluation context for the given scope
      #
      # When +bind+ responds to +class_eval+, a new binding is opened inside
      # that class and instance variables are transplanted into it. Otherwise
      # the fallback binding (whose +self+ is the spec instance) is returned.
      #
      # @param bind [Class, nil] the class scope
      #
      # @return [Binding]
      #
      # @example
      #   build_context(MyClass) # => Binding
      #
      # @api private
      #
      def build_context(bind)
        if bind.respond_to?(:class_eval)
          ctx = bind.class_eval('binding', __FILE__, __LINE__)
          transplant_instance_variables(ctx)
          ctx
        else
          @fallback_binding
        end
      end

      # Copies instance variables into an evaluation binding
      #
      # Sets each instance variable from the snapshot as a local, then
      # assigns it to the corresponding instance variable name via +eval+.
      # This makes hook-set state (e.g. +@flag+) available in class-scoped
      # bindings.
      #
      # @param ctx [Binding] the target binding
      #
      # @return [void]
      #
      # @example
      #   transplant_instance_variables(ctx)
      #
      # @api private
      #
      def transplant_instance_variables(ctx)
        @instance_variables.each do |ivar, value|
          local = "__yard_example_runner__#{ivar.to_s.delete('@')}"
          ctx.local_variable_set(local, value)
          ctx.eval("#{ivar} = #{local}")
        end
      end
    end
  end
end
