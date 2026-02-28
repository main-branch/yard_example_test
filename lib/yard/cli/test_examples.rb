# frozen_string_literal: true

# Extension of the {YARD} module provided by the `yard` gem
#
# This gem reopens the top-level {YARD} namespace from the `yard` dependency
# in order to register additional CLI commands.
#
# @api private
#
# @see https://rubydoc.info/docs/yard/YARD YARD
#
module YARD
  # Namespace for command-line interface components provided by the `yard` gem
  #
  # This gem reopens {YARD::CLI} to add the {YARD::CLI::TestExamples} command.
  #
  # @api private
  #
  # @see https://rubydoc.info/docs/yard/YARD/CLI YARD::CLI
  #
  module CLI
    # Implements the +yard test-examples+ command
    #
    # Registered with YARD's command dispatcher so that running
    # +yard test-examples [paths...] [options]+ invokes {#run}. The full
    # pipeline is:
    #
    # 1. {#parse_files} — expand the given paths/globs into +.rb+ file paths,
    #    defaulting to +app/+ and +lib/+ when none are given.
    # 2. {#parse_examples} — YARD-parse those files and collect every
    #    +@example+ tag from the registry.
    # 3. {#add_pwd_to_path} — ensure the current working directory is on
    #    +$LOAD_PATH+ so that +require+ calls inside examples resolve correctly.
    # 4. {#generate_tests} — convert each tag into a {YardExampleTest::Example}
    #    and register it as a +Minitest::Spec+.
    # 5. {#run_tests} — schedule the specs to run via +Minitest.autorun+ when
    #    the process exits.
    #
    # @see YardExampleTest::Example
    #
    # @see YardExampleTest::Expectation
    #
    # @api private
    #
    class TestExamples < Command
      # Returns the one-line description of the command shown in +yard help+
      #
      # @return [String] the description string
      def description
        'Run @example tags as tests'
      end

      # Runs the command line, parsing arguments and generating tests
      #
      # @param [Array<String>] args Switches are passed to minitest, everything else
      #   is treated as the list of directories/files or glob
      #
      # @return [void]
      #
      def run(*args)
        files = parse_files(args.grep_v(/^-/))
        examples = parse_examples(files)
        add_pwd_to_path
        generate_tests(examples)
        run_tests
      end

      private

      # Expands a list of glob patterns or directory names into Ruby source file paths
      #
      # Each entry in +globs+ is treated as follows:
      # - If it is an existing directory, +/**/*.rb+ is appended before
      #   expansion, recursively matching all Ruby files under that directory.
      # - Otherwise, it is passed directly to +Dir[]+ as-is, allowing explicit
      #   file paths or glob patterns.
      #
      # If +globs+ is empty, it defaults to +['app', 'lib']+.
      #
      # @param globs [Array<String>] file paths, directory names, or glob
      #   patterns to expand; defaults to +['app', 'lib']+ when empty
      #
      # @return [Array<String>] the flat list of +.rb+ file paths matched
      #   by expanding all globs; an empty array if no files are matched
      #
      def parse_files(globs)
        globs = %w[app lib] if globs.empty?

        files = globs.map do |glob|
          glob = "#{glob}/**/*.rb" if File.directory?(glob)

          Dir[glob]
        end

        files.flatten
      end

      # Parses the given Ruby source files and returns all +@example+ tags found
      #
      # Instructs YARD to parse +files+, excluding any files matched by the
      # patterns returned from {#excluded_files}. Once parsed, the full YARD
      # registry is loaded and every code object is inspected for +@example+
      # tags. The resulting tags from all objects are collected and flattened
      # into a single array.
      #
      # Note: YARD silently swallows parse-level errors (syntax errors,
      # +ArgumentError+, +NotImplementedError+) and logs warnings rather than
      # raising. Only OS-level I/O errors propagate.
      #
      # @param files [Array<String>] absolute or relative paths to the Ruby
      #   source files to parse
      #
      # @return [Array<YARD::Tags::Tag>] all +@example+ tags found across every
      #   documented code object in the parsed files, in registry order
      #
      # @raise [Errno::EACCES] if a file in +files+ exists but cannot be read
      #   due to insufficient permissions
      #
      # @raise [Errno::ENOENT] if a file in +files+ is deleted between directory
      #   expansion and the point at which YARD reads it
      #
      def parse_examples(files)
        YARD.parse(files, excluded_files)
        registry = YARD::Registry.load_all
        registry.all.map { |object| object.tags(:example) }.flatten
      end

      # Returns the list of file patterns to exclude from YARD parsing
      #
      # Reads the combined arguments from the command line and the +.yardopts+
      # file (via {YARD::Config.with_yardopts}) and extracts the values of any
      # +--exclude+ options. These patterns are passed directly to {YARD.parse}
      # which treats them as case-insensitive regular expressions.
      #
      # If +--exclude+ appears without a following value (e.g. as the last
      # argument), it is silently ignored.
      #
      # @return [Array<String>] the exclusion patterns, one per +--exclude+
      #   argument found; empty if none are present
      #
      def excluded_files
        excluded = []
        args = YARD::Config.with_yardopts { YARD::Config.arguments.dup }
        args.each_with_index do |arg, i|
          next unless arg == '--exclude'
          next if args[i + 1].nil?

          excluded << args[i + 1]
        end

        excluded
      end

      # Generates an in-memory Minitest spec for each +@example+ tag
      #
      # Calls {#build_spec} to construct a {YardExampleTest::Example} for
      # each tag, then calls +generate+ on it, which dynamically defines and
      # registers an anonymous +Minitest::Spec+ subclass. The registered specs
      # are held in memory by Minitest and executed when {#run_tests} triggers
      # the test run.
      #
      # @param examples [Array<YARD::Tags::Tag>] the +@example+ tags to convert
      #   into Minitest specs, as returned by {#parse_examples}
      #
      # @return [void]
      #
      def generate_tests(examples)
        examples.each do |example|
          build_spec(example).generate
        end
      end

      # Builds a {YardExampleTest::Example} from a YARD +@example+ tag
      #
      # Constructs a new {YardExampleTest::Example} and populates it with
      # the metadata needed to generate and run a Minitest spec:
      #
      # - +name+ — the title from the +@example+ tag (e.g. +"Adding two numbers"+),
      #   or an empty string if the tag has no title
      # - +definition+ — the YARD path of the owning code object
      #   (e.g. +"MyClass#my_method"+), used as the spec description
      # - +filepath+ — the absolute path and line number of the code object's
      #   definition (e.g. +"/project/lib/my_class.rb:10"+), used to enrich
      #   failure backtraces
      # - +expectations+ — the list of expectations parsed from the example body
      #   by {#extract_expectations}
      #
      # @param example [YARD::Tags::Tag] a single +@example+ tag whose +object+,
      #   +name+, and +text+ attributes will be used to populate the spec
      #
      # @return [YardExampleTest::Example] the populated example object, ready
      #   to have +generate+ called on it
      #
      def build_spec(example)
        YardExampleTest::Example.new(example.name).tap do |spec|
          spec.definition = example.object.path
          spec.filepath = "#{Dir.pwd}/#{example.object.files.first.join(':')}"
          spec.expectations = extract_expectations(example)
        end
      end

      # Parses the body of a YARD +@example+ tag into expectations
      #
      # Parses the body of a YARD +@example+ tag into a list of
      # {YardExampleTest::Expectation} objects
      #
      # The example body is first normalized by {#normalize_example_lines}, which
      # puts each +#=>+ annotation on its own line and strips whitespace. The
      # resulting lines are then consumed in chunks:
      #
      # 1. All lines up to (but not including) the next +#=>+ line are joined as the
      #    +actual+ Ruby expression.
      # 2. The +#=>+ line that follows (if any) is stripped of its prefix and
      #    whitespace to form the +expected+ value string.
      # 3. An {YardExampleTest::Expectation} is appended to the result array and
      #    the process repeats.
      #
      # If a chunk of code lines has no following +#=>+ line, +expected+ is set to
      # +nil+, which signals to the test runner that the expression should be
      # evaluated but not asserted against a specific value.
      #
      # @example Parsing a single expectation tag.text = "sum(1, 2) #=> 3"
      #   extract_expectations(tag) #=> [Expectation[actual: "sum(1, 2)", expected:
      #   "3"]]
      #
      # @example Parsing multiple expectations with shared setup tag.text = "a =
      #   1\nsum(a, 2) #=> 3\nsum(a, 3) #=> 4" extract_expectations(tag) #=>
      #   [Expectation[actual: "a = 1\nsum(a, 2)", expected: "3"],
      #   #    Expectation[actual: "sum(a, 3)", expected: "4"]]
      #
      # @param example [YARD::Tags::Tag] the +@example+ tag whose +text+ body will be
      #   parsed into expectations
      #
      # @return [Array<YardExampleTest::Expectation>] one +Expectation+ per +#=>+
      #   annotation found in the example body; each holds:
      #   - +actual+ [String] — one or more lines of Ruby code to evaluate
      #   - +expected+ [String, nil] — the expected return value, or +nil+ if the
      #     expression should be evaluated without asserting a result
      #
      def extract_expectations(example)
        lines = normalize_example_lines(example.text)
        [].tap do |arr|
          until lines.empty?
            actual = lines.take_while { |l| l !~ /^#=>/ }
            expected = lines[actual.size]&.sub('#=>', '')&.strip
            lines.slice! 0..actual.size
            arr << YardExampleTest::Expectation.new(actual: actual.join("\n"), expected: expected)
          end
        end
      end

      # Normalizes the raw text of a +@example+ tag into a flat array of lines
      #
      # Performs three transformations in order:
      #
      # 1. Normalizes the +# =>+ annotation style (with a space) to +#=>+
      #    (without a space), so both forms are treated identically.
      # 2. Ensures each +#=>+ annotation is on its own line by inserting a
      #    newline before every occurrence. This handles inline annotations
      #    such as +sum(1, 2) #=> 3+, splitting them into two lines.
      # 3. Splits on newlines, strips leading and trailing whitespace from
      #    each line, and discards any blank lines.
      #
      # The resulting array is consumed by {#extract_expectations} to identify
      # code lines and their corresponding +#=>+ assertion lines.
      #
      # @param text [String] the raw body text of a +@example+ tag
      #
      # @return [Array<String>] the normalized, non-empty lines of the example;
      #   +#=>+ lines are always separate entries, never inline with code
      #
      def normalize_example_lines(text)
        text = text.gsub('# =>', '#=>')
        text = text.gsub('#=>', "\n#=>")
        text.split("\n").map(&:strip).reject(&:empty?)
      end

      # Schedules the generated Minitest specs to run when the process exits
      #
      # Calls +Minitest.autorun+, which registers an +at_exit+ hook. That hook
      # calls +Minitest.run+ and then fires any callbacks registered via
      # +Minitest.after_run+ (including {YardExampleTest.after_run} blocks).
      #
      # +Minitest.autorun+ is used rather than calling +Minitest.run+ directly
      # because +Minitest.after_run+ callbacks are only invoked inside
      # +autorun+'s +at_exit+ handler — a bare +Minitest.run+ call does not
      # trigger them.
      #
      # @return [void]
      #
      def run_tests
        Minitest.autorun
      end

      # Adds the current working directory to Ruby's load path if not present
      #
      # Example code in +@example+ tags is evaluated in the same Ruby process
      # as +yard test-examples+. That code commonly uses +require+ to load the
      # project's own files (e.g. +require 'lib/my_class'+), but Ruby's default
      # +$LOAD_PATH+ does not include the current working directory. Without
      # this, those +require+ calls would raise +LoadError+.
      #
      # This method must be called before {#generate_tests} so that any
      # +require+ statements executed during example evaluation can resolve
      # paths relative to the project root.
      #
      # @return [void]
      #
      def add_pwd_to_path
        $LOAD_PATH.unshift(Dir.pwd) unless $LOAD_PATH.include?(Dir.pwd)
      end
    end
  end
end
