# frozen_string_literal: true

module YardExampleTest
  class Example < ::Minitest::Spec
    # Isolates constant definitions introduced during example evaluation
    #
    # Resolves the top-level class or module for a YARD definition path,
    # snapshots the constants on both +Object+ and that scope, yields control
    # to the caller, then removes any constants that were added during the
    # block. This prevents one example's constant definitions from leaking
    # into subsequent examples.
    #
    # @example
    #   ConstantSandbox.new('MyClass#foo').isolate do |scope|
    #     # evaluate code that may define constants…
    #   end
    #   # any constants defined inside the block are now removed
    #
    class ConstantSandbox
      # Creates a sandbox for the given YARD definition path
      #
      # @param definition [String] a YARD path such as +"MyClass#method"+ or
      #   +"MyClass.method"+
      #
      # @example
      #   ConstantSandbox.new('MyClass#foo')
      #
      # @api private
      #
      def initialize(definition)
        @scope = resolve_scope(definition)
      end

      # Snapshots constants, yields the resolved scope, then cleans up
      #
      # Any constants added to +Object+ or the resolved scope during the
      # block are removed when the block returns (or raises), with one
      # exception: constants added to +Object+ whose source file was newly
      # loaded via +require+ during the block are preserved. This prevents
      # one example's constant definitions from leaking into subsequent
      # examples while still allowing +require+ calls to have their normal
      # lasting effect (re-requiring a cached file would be a no-op, so
      # stripping those constants would cause +NameError+ in later examples).
      #
      # The resolved scope is yielded so that callers can use it as the
      # evaluation binding.
      #
      # @yield [scope] gives the resolved class/module (or +nil+) to the block
      # @yieldparam scope [Class, Module, nil] the resolved scope constant
      #
      # @return [void]
      #
      # @example
      #   sandbox.isolate { |scope| scope.class_eval(code) }
      #
      # @api private
      #
      def isolate
        global_before = Object.constants
        scope_before  = @scope.respond_to?(:constants) ? @scope.constants : nil
        loaded_before = $LOADED_FEATURES.dup

        yield @scope
      ensure
        loaded_during = $LOADED_FEATURES - loaded_before
        clear_extra_constants(Object, global_before, skip_if_loaded_by: loaded_during)
        clear_extra_constants(@scope, scope_before) if scope_before
      end

      private

      # Resolves the top-level class or module constant for a YARD definition path
      #
      # Extracts the leading constant name from +definition+ (the portion before
      # the first +#+ or +.+ separator), then returns the corresponding constant
      # from +Object+ if it exists. Returns +nil+ if the definition does not start
      # with a constant name or if the constant is not currently defined.
      #
      # @param definition [String] a YARD path such as +"MyClass#method"+
      #
      # @return [Class, Module, nil] the resolved constant, or +nil+
      #
      # @example
      #   resolve_scope('MyClass#foo') # => MyClass
      #
      # @api private
      #
      def resolve_scope(definition)
        name = definition.split(/#|\./).first
        Object.const_get(name) if name&.match?(/\A[A-Z]/) && Object.const_defined?(name)
      end

      # Removes constants from +scope+ that were not present in +before+
      #
      # When +skip_if_loaded_by+ is non-empty, any constant on +scope+ whose
      # source file (as reported by +Module#const_source_location+) appears in
      # +skip_if_loaded_by+ is preserved rather than removed. This is used to
      # retain constants introduced by +require+ calls during example evaluation.
      #
      # @param scope [Module] the scope to clean up
      # @param before [Array<Symbol>] the constant names present before evaluation
      # @param skip_if_loaded_by [Array<String>] absolute paths of files newly
      #   loaded during evaluation; constants defined in these files are kept
      #
      # @return [void]
      #
      # @example
      #   clear_extra_constants(Object, before_constants)
      #
      # @api private
      #
      def clear_extra_constants(scope, before, skip_if_loaded_by: [])
        (scope.constants - before).each do |constant|
          if skip_if_loaded_by.any?
            source_file, = scope.const_source_location(constant.to_s)
            next if source_file && skip_if_loaded_by.include?(source_file)
          end
          scope.__send__(:remove_const, constant)
        end
      end
    end
  end
end
