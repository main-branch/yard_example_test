Feature: yard test-examples
  In order to avoid publishing code examples that are broken
  As a developer
  I want to automatically parse YARD's @example tags
  And use them as tests

  Background:
    # YARD stopped auto-loading all plugins at 0.6.2, so anything newer needs
    # the plugin explicitly loaded. A simple way to do this is to always have
    # a `.yardopts` that loads `yard_example_test`.
    Given a file named ".yardopts" with:
      """
      --plugin yard_example_test
      """

  Scenario: adds new command to yard
    When I run `bundle exec yard --help`
    Then the output should contain "test-examples Run @example tags as tests"

  Scenario: looks for files in app/lib directories by default
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      require 'lib/lib'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2) #=> 4
      def sum(one, two)
        one + two
      end
      """
    And a file named "lib/lib.rb" with:
      """
      # @example
      #   sub(2, 2) #=> 0
      def sub(one, two)
        one - two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "2 runs, 2 assertions, 0 failures, 0 errors, 0 skips"

  Scenario Outline: looks for files only in passed glob
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      require 'lib/lib'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2) #=> 4
      def sum(one, two)
        one + two
      end
      """
    And a file named "lib/lib.rb" with:
      """
      # @example
      #   sub(2, 2) #=> 0
      def sub(one, two)
        one - two
      end
      """
    When I run `bundle exec yard test-examples <glob>`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"
    Examples:
      | glob        |
      | app         |
      | app/*.rb    |
      | app/**      |
      | app/**/*.rb |
      | app/app.rb  |

  Scenario: generates test names from unit name
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2) #=> 4
      def sum(one, two)
        one + two
      end

      module A
        # @example
        #   sub(2, 2) #=> 0
        def sub(one, two)
          one - two
        end
      end

      class B
        # @example
        #   B.multiply(3, 3) #=> 9
        def self.multiply(one, two)
          one * two
        end

        # @example
        #   div(9, 3) #=> 3
        def div(one, two)
          one / two
        end
      end
      """
    When I run `bundle exec yard test-examples -v`
    Then the output should contain "#sum"
    And the output should contain "A#sub"
    And the output should contain "B.multiply"
    And the output should contain "B#div"

  Scenario: fails if exception is raised
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   foo
      def foo
        raise 'Fails with exception'
      end
      """
    When I run `bundle exec yard test-examples`
    Then the exit status should be 1
    And the output should contain "1) Error:"
    And the output should contain "#foo#test_0001_:"
    And the output should contain "RuntimeError: Fails with exception"
    And the output should contain "app/app.rb:4:"

  Scenario: asserts using equality
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(1, 1) #=> 2
      def sum(one, two)
        (one + two).to_s
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain:
      """
      --- expected
      +++ actual
      @@ -1 +1,3 @@
      -2
      +# encoding: US-ASCII
      +#    valid: true
      +"2"
      """

  Scenario: asserts exceptions
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   divide(1, 0) #=> raise ZeroDivisionError, "divided by 0"
      def divide(one, two)
        one / two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario Outline: properly handles different return values
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   foo #=> <value>
      def foo
        <value>
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"
    And the output should not contain "DEPRECATED"
    Examples:
      | value |
      | true  |
      | false |
      | nil   |
      | ''    |
      | ""    |
      | []    |
      | {}    |
      | Class |
      | 0     |
      | 10    |
      | -1    |
      | 1.0   |

  Scenario Outline: properly handles case equality
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   foo #=> <value>
      def foo
        'string'
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"
    Examples:
      | value    |
      | 'string' |
      | /string/ |
      | String   |

  Scenario: handles multiple @example tags
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2) #=> 4
      # @example
      #   sum(3, 3) #=> 6
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "2 runs, 2 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: handles multiple return comments
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   a = 1
      #   sum(a, 2) #=> 3
      #   sum(a, 3) #=> 4
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 2 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: runs @example tags without return comment
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2)
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 0 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: handles `# =>` return comment
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2) # => 4
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: handles return comment on newline
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2)
      #   #=> 4
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: handles multiple lines
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   a = 1
      #   b = 2
      #   sum(a, b)
      #   #=> 3
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: names test with example title when it's present
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example sums two numbers
      #   sum(2, 2) #=> 4
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples -v`
    Then the output should contain "#sum#test_0001_sums two numbers"

  Scenario: doesn't name test when title is not present
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2) #=> 4
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples -v`
    Then the output should contain "#sum#test_0001_"

  Scenario: adds unit definition to backtrace on failures
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2) #=> 5
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "app/app.rb:3"

  Scenario: has rake task to run the tests
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2) #=> 4
      def sum(one, two)
        one + two
      end
      """
    And a file named "Rakefile" with:
      """
      require 'yard_example_test/rake'
      YardExampleTest::RakeTask.new do |task|
        task.test_examples_opts = %w[-v]
        task.pattern = 'app/**/*.rb'
      end
      """
    When I run `bundle exec rake yard:test-examples`
    Then the exit status should be 0
    And the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: propagates exit code to rake task
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(2, 2) #=> 5
      def sum(one, two)
        one + two
      end
      """
    And a file named "Rakefile" with:
      """
      require 'yard_example_test'
      YardExampleTest::RakeTask.new
      """
    When I run `bundle exec rake yard:test-examples`
    Then the exit status should be 1

  Scenario Outline: requires example test helper
    Given a file named "<directory>/example_test_helper.rb" with:
      """
      require 'app/app'

      def a
        2
      end

      def b
        2
      end
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   sum(a, b) #=> 4
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"
    Examples:
      | directory |
      | .         |
      | support   |
      | spec      |
      | test      |

  Scenario: shares binding between asserts
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   a, b = 1, 2
      #   sum(a, b) #=> 3
      #   a = 2
      #   sum(a, b) #=> 4
      def sum(one, two)
        one + two
      end

      module App
        # @example
        #   src = {foo: 'bar'}
        #   src[:foo] #=> 'bar'
        #   src[:foo] #=> 'bar'
        def foo
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "2 runs, 4 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: does not share binding between examples
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   a, b = 1, 2
      #   sum(a, b) #=> 3
      #
      # @example
      #   sum(a, b) #=> 4
      def sum(one, two)
        one + two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should match /NameError: undefined local variable or method [`']a'/

  Scenario: supports global hooks
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      YardExampleTest.configure do |runner|
        runner.before { @flag = false  }
        runner.after { @flag = true  }
        runner.after_run { puts 'Run after all by minitest' }
      end
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   flag #=> false
      def flag
        @flag
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"
    And the output should contain "Run after all by minitest"

  Scenario: supports test-name hooks
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      YardExampleTest.before do
        @flag = true
        @foo = true
      end

      YardExampleTest.before('#flag') do
        @flag = false
        @foo = false
      end
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   flag #=> false
      def flag
        @flag && @foo
      end

      # @example
      #   foo #=> true
      def foo
        @foo && @flag
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "2 runs, 2 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: supports global and test-name hooks
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      YardExampleTest.configure do |runner|
        runner.before { @one = true  }
        runner.before('#foo') { @two = true  }
      end
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   foo #=> true
      def foo
        @one && @two
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: supports class-name hooks
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      YardExampleTest.configure do |runner|
        runner.before('A') do
          @flag = true
        end
      end
      """
    And a file named "app/app.rb" with:
      """
      class A
        # @example
        #   A.flag #=> true
        def self.flag
          @flag
        end

        # @example
        #   A::Nested.flag #=> true
        class Nested
          def self.flag
            @flag
          end
        end
      end

      class B
        # @example
        #   B.flag #=> nil
        def self.flag
          @flag
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "3 runs, 3 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: supports test-name hooks for multiple examples on the same code object
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      YardExampleTest.before('#flag') do
        @flag = true
      end

      YardExampleTest.before('#flag@Second example for flag') do
        @flag = false
      end
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   flag #=> true
      # @example Second example for flag
      #   flag #=> false
      def flag
        @flag
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "2 runs, 2 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: passes example to hooks to allow for inspection
    Given a file named "example_test_helper.rb" with:
      """
      YardExampleTest.before do |example|
        require example.filepath.split(':').first
      end
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   App.foo #=> 'bar'
      class App
        def self.foo
          'bar'
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: can skip tests
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      YardExampleTest.configure do |runner|
        runner.skip '#flag'
        runner.skip 'A.foo'
      end
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   flag #=> false
      def flag
        @flag
      end

      class A
        # @example
        #   A.foo #=> true
        def self.foo
          true
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "0 runs, 0 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: skips class names as substrings in class and method paths
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      YardExampleTest.configure do |runner|
        runner.skip 'A'
      end
      """
    And a file named "app/app.rb" with:
      """
      class A
        # @example
        #   A.value #=> 1
        def self.value
          1
        end
      end

      class Another
        # @example
        #   Another.value #=> 2
        def self.value
          2
        end
      end

      class B
        # @example
        #   B.value #=> 3
        def self.value
          3
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: does not skip by named example qualifier
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      YardExampleTest.configure do |runner|
        runner.skip 'A.value@Second example'
      end
      """
    And a file named "app/app.rb" with:
      """
      class A
        # @example First example
        #   A.value #=> 1
        #
        # @example Second example
        #   A.value #=> 1
        def self.value
          1
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "2 runs, 2 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: allows binding to local context
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      class App
        # @example
        #   a, b = 1, 2
        #   sum(a, b) #=> 3
        def self.sum(one, two)
          one + two
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: shares instance variables in local context binding
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      YardExampleTest.before do
        @flag = true
      end
      """
    And a file named "app/app.rb" with:
      """
      class App
        # @example
        #   @flag #=> true
        def self.foo
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: isolates constants per test
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   ::FOO = 123
      #   ::FOO #=> 123
      #   ::BAR #=> raise NameError, 'uninitialized constant BAR'
      #   FOO = 456
      #   FOO #=> 456
      #   BAR #=> raise NameError, 'uninitialized constant App::BAR'
      #
      # @example
      #   ::BAR = 123
      #   ::BAR #=> 123
      #   ::FOO #=> raise NameError, 'uninitialized constant FOO'
      #   BAR = 123
      #   BAR #=> 123
      #   FOO #=> raise NameError, 'uninitialized constant App::FOO'
      class App
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "2 runs, 8 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: allows to run a single test
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      class A
        # @example First
        #   A.foo #=> true
        #
        # @example Second
        #   A.foo #=> false
        def self.foo
          true
        end
      end
      """
    When I run `bundle exec yard test-examples -v --name=/First/`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"
    When I run `bundle exec yard test-examples -v --name=/Second/`
    Then the output should contain "1 runs, 1 assertions, 1 failures, 0 errors, 0 skips"

  Scenario: ignores files excluded in .yardopts
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      require 'lib/lib'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   foo
      def foo
        "I should be run"
      end
      """
    And a file named "lib/lib.rb" with:
      """
      # @example
      #   bar
      def bar
        raise "I should be ignored"
      end
      """
    And a file named ".yardopts" with:
      """
      --plugin yard_example_test
      --exclude lib/lib.rb
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 0 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: shows exception when assert raises one
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   foo #=> 1
      def foo
        raise 'Fails with exception'
      end
      """
    When I run `bundle exec yard test-examples`
    Then the exit status should be 1
    And the output should contain "1) Error:"
    And the output should contain "#foo#test_0001_:"
    And the output should contain "RuntimeError: Fails with exception"
    And the output should contain "app/app.rb:4:"

  Scenario: handles a proc successfully
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   MyClass.call #=> 1
      MyClass = lambda { 1 }
      """
      When I run `bundle exec yard test-examples`
      Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: supports RSpec value matchers on the right side of #=>
    Given a file named "example_test_helper.rb" with:
      """
      require 'rspec/expectations'
      require 'rspec/matchers'
      require 'app/app'

      YardExampleTest::Example.include RSpec::Matchers
      """
    And a file named "app/app.rb" with:
      """
      class App
        # @example approximate match
        #   App.pi #=> be_within(0.01).of(3.14)
        def self.pi
          Math::PI
        end

        # @example kind of check
        #   App.greeting #=> a_kind_of(String)
        def self.greeting
          'hello'
        end

        # @example collection inclusion
        #   App.numbers #=> include(2, 3)
        def self.numbers
          [1, 2, 3, 4, 5]
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "3 runs, 3 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: supports RSpec block matchers on the right side of #=>
    Given a file named "example_test_helper.rb" with:
      """
      require 'rspec/expectations'
      require 'rspec/matchers'
      require 'app/app'

      YardExampleTest::Example.include RSpec::Matchers
      """
    And a file named "app/app.rb" with:
      """
      class App
        # @example raises ZeroDivisionError
        #   App.divide(1, 0) #=> raise_error(ZeroDivisionError)
        #
        # @example raises with message pattern
        #   App.divide(1, 0) #=> raise_error(ZeroDivisionError, /divided/)
        def self.divide(a, b)
          a / b
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "2 runs, 2 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: supports custom matchers implementing the matches? protocol
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      class BePositive
        def matches?(actual)
          @actual = actual
          actual > 0
        end

        def failure_message
          "expected #{@actual} to be positive"
        end
      end

      def be_positive
        BePositive.new
      end
      """
    And a file named "app/app.rb" with:
      """
      class App
        # @example
        #   App.count #=> be_positive
        def self.count
          42
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: supports custom block matchers via supports_block_expectations?
    Given a file named "example_test_helper.rb" with:
      """
      require 'app/app'

      class RaiseNameError
        def supports_block_expectations?
          true
        end

        def matches?(actual)
          actual.call
          false
        rescue NameError
          true
        end

        def failure_message
          'expected block to raise NameError'
        end
      end

      def raise_name_error
        RaiseNameError.new
      end
      """
    And a file named "app/app.rb" with:
      """
      class App
        # @example
        #   App.raise_missing #=> raise_name_error
        def self.raise_missing
          unknown_name
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"

  Scenario: properly supports calculating coverage
    Given a file named "example_test_helper.rb" with:
      """
      require 'simplecov'

      SimpleCov.start

      require 'app/app'
      """
    And a file named "app/app.rb" with:
      """
      # @example
      #   MyClass.call #=> 1
      class MyClass
        def self.call
          1
        end
      end
      """
    When I run `bundle exec yard test-examples`
    Then the output should contain "1 runs, 1 assertions, 0 failures, 0 errors, 0 skips"
    And the output should contain "100.0%"
