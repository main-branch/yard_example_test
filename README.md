<!--
# @markup markdown
# @title README
-->

# yard_example_runner

![Gem Version](https://img.shields.io/gem/v/yard_example_runner?label=gem%20version&color=green)
[![Continuous Integration](https://github.com/main-branch/yard_example_runner/actions/workflows/continuous-integration.yml/badge.svg)](https://github.com/main-branch/yard_example_runner/actions/workflows/continuous-integration.yml)
[![YARD Docs](https://img.shields.io/badge/docs-rubydoc.info-green.svg)](https://www.rubydoc.info/gems/yard_example_runner)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.txt)

`YardExampleRunner` is a YARD plugin that automatically parses `@example` tags in
your documentation and executes them as tests ensuring code examples remain
accurate and serve as a living, executable specification.

Annotate `@example` code with **expectation operators** (`#=>`):

```ruby
# @example
#   "hello".upcase #=> "HELLO"
```

Each expectation operator verifies the actual value on the left against the expected
value on the right.

This project is derived from [yard-doctest](https://github.com/p0deje/yard-doctest),
created by [Alex Rodionov](https://github.com/p0deje) and contributors.

- [Installation](#installation)
- [Basic usage](#basic-usage)
- [Advanced usage](#advanced-usage)
  - [Verifying raised exceptions](#verifying-raised-exceptions)
  - [Shared example context](#shared-example-context)
  - [Hooks](#hooks)
  - [Skipping examples](#skipping-examples)
  - [Using matchers (optional)](#using-matchers-optional)
    - [RSpec matchers](#rspec-matchers)
    - [Minitest matchers](#minitest-matchers)
    - [Custom matchers](#custom-matchers)
  - [Rake task](#rake-task)
- [Contributing](#contributing)

## Installation

Add `yard_example_runner` as a development dependency:

```bash
bundle add yard_example_runner --group development
```

Or add it manually to your Gemfile and run `bundle install`:

```ruby
gem 'yard_example_runner', group: :development
```

## Basic usage

Consider a simple geometry library:

```text
lib/
  rectangle.rb
  circle.rb
```

Each file contains a class with documented examples:

```ruby
# rectangle.rb
class Rectangle
  # @example
  #   Rectangle.shape_name #=> 'rectangle'
  def self.shape_name
    'rectangle'
  end

  def initialize(width, height)
    @width = width
    @height = height
  end

  # @example Unit square
  #   rect = Rectangle.new(1, 1)
  #   rect.area #=> 1
  #
  # @example Standard rectangle
  #   rect = Rectangle.new(4, 5)
  #   rect.area #=> 20
  #
  # @example Non-integer dimensions
  #   rect = Rectangle.new(2.5, 4.0)
  #   rect.area #=> 10.0
  def area
    @width * @height
  end
end
```

```ruby
# circle.rb
class Circle
  # @example
  #   Circle.shape_name #=> 'rectangle'
  def self.shape_name
    'circle'
  end

  # @example Unit circle
  #   circle = Circle.new(1)
  #   circle.area.round(4) #=> 3.1416
  def initialize(radius)
    @radius = radius
  end

  def area
    Math::PI * @radius**2
  end
end
```

First, tell YARD to automatically load `yard_example_runner` by adding it as a plugin
in your `.yardopts`:

```text
# .yardopts
--plugin yard_example_runner
```

Next, create a test helper that loads everything your examples need to run. It serves
a similar purpose to `spec_helper.rb` in RSpec or `test_helper.rb` in Minitest:

```bash
touch example_runner_helper.rb
```

```ruby
# example_runner_helper.rb
require 'lib/rectangle'
require 'lib/circle'
```

Now run your examples:

```bash
$ bundle exec yard run-examples
Run options: --seed 5974

# Running:

..F...

Finished in 0.015488s, 387.3967 runs/s, 387.3967 assertions/s.

  1) Failure:
Circle.shape_name#test_0001_ [lib/circle.rb:3]:
Expected: "rectangle"
  Actual: "circle"

6 runs, 6 assertions, 1 failures, 0 errors, 0 skips
```

The `Circle.shape_name` example contains a copy-paste error. Correct it and run the
command again:

```bash
$ sed -i.bak "s/#=> 'rectangle'/#=> 'circle'/" lib/circle.rb
$ bundle exec yard run-examples
Run options: --seed 51966

# Running:

......

Finished in 0.002712s, 2212.3894 runs/s, 2212.3894 assertions/s.

6 runs, 6 assertions, 0 failures, 0 errors, 0 skips
```

Each expectation operator verifies the actual value on the left against the expected
value on the right. The right-hand side can be a plain value, a regular expression, a
range, or a matcher object (such as an RSpec, Minitest, or custom matcher) — each
evaluated according to its own `===` or `matches?` semantics rather than simple `==`
equality.

A single example can contain multiple expectation operators:

```ruby
class Rectangle
  # @example
  #   small = Rectangle.new(1, 2)
  #   small.area #=> 2
  #   large = Rectangle.new(3, 4)
  #   large.area #=> 12
  def area
    @width * @height
  end
end
```

This runs as a single test with multiple expectation operators:

```bash
$ bundle exec yard run-examples lib/rectangle.rb
# ...
1 runs, 2 assertions, 0 failures, 0 errors, 0 skips
```

Examples without any expectation operators are still executed to verify that no
exceptions are raised:

```ruby
class Rectangle
  # @example
  #   rect = Rectangle.new(2, 3)
  #   rect.area
  def area
    @width * @height
  end
end
```

```bash
$ bundle exec yard run-examples lib/rectangle.rb
# ...
1 runs, 0 assertions, 0 failures, 0 errors, 0 skips
```

Test execution is delegated to [minitest](https://github.com/minitest/minitest). Each
example is registered as an `it` block within a dynamically generated
`Minitest::Spec` subclass.

## Advanced usage

### Verifying raised exceptions

To verify that an example raises an exception, use `raise` on the right-hand side of
the expectation operator, specifying the exception class and message:

```ruby
class Calculator
  # @example
  #   divide(1, 0) #=> raise ZeroDivisionError, "divided by 0"
  def divide(one, two)
    one / two
  end
end
```

The raised exception is matched by comparing a string containing its class name and
message. The expected message must **exactly** match the message raised at runtime.

For more flexible exception matching — such as matching by class only or using a
regex on the message — see [RSpec matchers](#rspec-matchers), which supports
`raise_error`.

### Shared example context

Shared example context is about making objects and methods available to examples. The
`example_runner_helper.rb` file introduced in [Basic usage](#basic-usage) is loaded
before examples execute. Place shared helper methods there (or in
`support/example_runner_helper.rb`, `spec/example_runner_helper.rb`, or
`test/example_runner_helper.rb`).

For instance, if an example references an object without constructing it:

```ruby
class Rectangle
  # @example Area of a shared rectangle
  #   rect.area #=> 20
  def area
    @width * @height
  end
end
```

Running this will fail because `rect` is not defined in the example:

```bash
$ bundle exec yard run-examples
  # ...
  1) Error:
Rectangle#area#test_0001_Area of a shared rectangle:
NameError: undefined local variable or method `rect' for Object:Class
  # ...
```

Define `rect` as a memoized method in `example_runner_helper.rb` to make it available
across all examples:

```ruby
# example_runner_helper.rb
require 'lib/rectangle'
require 'lib/circle'

def rect
  @rect ||= Rectangle.new(4, 5)
end
```

### Hooks

Hooks are lifecycle callbacks that run around each example, providing setup and
teardown behavior. They are defined in `example_runner_helper.rb` using
`YardExampleRunner.configure`:

```ruby
YardExampleRunner.configure do |runner|
  runner.before do
    # Runs before each example.
    # Evaluated in the same context as the example,
    # so instance variables are shared.
  end

  runner.after do
    # Runs after each example.
    # Also evaluated in the same context as the example.
  end

  runner.after_run do
    # Runs once after all examples have finished.
    # Evaluated in a separate context; instance variables
    # from individual examples are not accessible here.
  end
end
```

Hooks can be scoped to a specific class, method, or named example by passing a
qualifier string:

```ruby
YardExampleRunner.configure do |runner|
  runner.before('MyClass') do
    # Runs before every example in `MyClass` and its methods
    # (e.g. `MyClass.foo`, `MyClass#bar`)
  end

  runner.after('MyClass#foo') do
    # Runs after every example for `MyClass#foo`
  end

  runner.before('MyClass#foo@Example one') do
    # Runs before only the example named "Example one" in `MyClass#foo`
  end
end
```

### Skipping examples

Examples can be excluded from a run by passing a class or method qualifier to
`runner.skip` in `example_runner_helper.rb`. The qualifier is matched as a substring
of the example's class/method path, so skipping a class also skips all of its
methods:

```ruby
YardExampleRunner.configure do |runner|
  runner.skip 'MyClass'     # skips all examples in `MyClass` and its methods
  runner.skip 'MyClass#foo' # skips all examples for `MyClass#foo` only
end
```

Note that `skip` matches against the class/method path only. Skipping by named
example (e.g. `MyClass#foo@Example one`) is not supported; use a scoped
[hook](#hooks) to conditionally skip at that level of granularity.

### Using matchers (optional)

The right-hand side of an expectation operator supports any object that implements
`matches?`. Matchers that also implement `failure_message` (or
`failure_message_for_should`) produce better
failure output. This includes [RSpec
matchers](https://rspec.info/documentation/3.12/rspec-expectations/),
[minitest-matchers](https://github.com/wojtekmach/minitest-matchers) or
[minitest-matchers_vaccine](https://github.com/rmm5t/minitest-matchers_vaccine), and
any custom matcher you write yourself.

#### RSpec matchers

Add `rspec-expectations` as a development dependency:

```ruby
gem 'rspec-expectations', group: :development
```

Include `RSpec::Matchers` in `example_runner_helper.rb`:

```ruby
# example_runner_helper.rb
require 'rspec/expectations'
require 'rspec/matchers'

YardExampleRunner::Example.include RSpec::Matchers
```

##### Value matchers

Matchers like `eq`, `be_within`, `a_kind_of`, and `include` are compared against the
evaluated actual value:

```ruby
class Calculator
  # @example
  #   Calculator.pi #=> be_within(0.01).of(3.14)
  def self.pi
    Math::PI
  end

  # @example
  #   Calculator.describe(42) #=> a_kind_of(String) & match(/positive/)
  def self.describe(n)
    n > 0 ? "positive number" : "non-positive number"
  end
end
```

##### Block matchers

Matchers like `raise_error`, `change`, and `output` receive the actual expression as
a callable block, so the matcher can invoke it and inspect side-effects:

```ruby
class Calculator
  # @example
  #   Calculator.divide(1, 0) #=> raise_error(ZeroDivisionError)
  #
  # @example with message pattern
  #   Calculator.divide(1, 0) #=> raise_error(ZeroDivisionError, /divided/)
  def self.divide(a, b)
    a / b
  end
end
```

The expected side of an expectation operator is evaluated outside the documented
class's namespace, so matchers like `include` are never shadowed by Ruby's built-in
`Module#include`.

#### Minitest matchers

If you prefer to stay within the Minitest ecosystem, gems like
[minitest-matchers](https://github.com/wojtekmach/minitest-matchers) and
[minitest-matchers_vaccine](https://github.com/rmm5t/minitest-matchers_vaccine)
can be used alongside `yard_example_runner`. Add one as a development dependency:

```ruby
gem 'minitest-matchers_vaccine', group: :development
```

If you use `minitest-matchers_vaccine`, require it in `example_runner_helper.rb`:

```ruby
# example_runner_helper.rb
require 'minitest/matchers_vaccine'
```

`yard_example_runner` does not require including a matcher module on
`YardExampleRunner::Example`. Any matcher object that follows the `matches?` /
`failure_message` protocol is recognized automatically.

#### Custom matchers

Any object that responds to `matches?` works as a matcher.
No external dependencies are required:

```ruby
# example_runner_helper.rb
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
```

```ruby
class Counter
  # @example
  #   Counter.total #=> be_positive
  def self.total
    42
  end
end
```

Block matchers additionally respond to `supports_block_expectations?` returning
`true`, which tells `yard_example_runner` to wrap the actual expression in a proc
before passing it to `matches?`.

### Rake task

A Rake task is available for integrating example runs into your build pipeline:

```ruby
# Rakefile
require 'yard_example_runner/rake'

YardExampleRunner::RakeTask.new do |task|
  task.run_examples_opts = %w[-v]
  task.pattern = 'lib/**/*.rb'
end
```

```bash
bundle exec rake yard:run-examples
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution workflow and requirements.

Minimum expectations:

1. Fork the repository and create a feature branch.
2. Run `bin/setup` to install development dependencies.
3. Make your changes and ensure `bundle exec rake` passes.
4. Use [Conventional Commits](https://www.conventionalcommits.org/) for all commits.
5. Open a pull request with a clear description of the change.
