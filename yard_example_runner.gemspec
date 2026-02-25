# frozen_string_literal: true

version = File.read(File.expand_path('lib/yard_example_runner/version.rb', __dir__)).match(/VERSION = ['"](.*?)['"]/)[1]

Gem::Specification.new do |spec|
  spec.name         = 'yard_example_runner'
  spec.summary      = 'A YARD plugin that executes @example tag code as tests'
  spec.description  = 'yard_example_runner parses @example tags from YARD documentation and ' \
                      'executes them as tests, ensuring code examples remain accurate ' \
                      'and serve as a living, executable specification.'
  spec.author       = 'James Couball'
  spec.email        = 'jcouball@yahoo.com'
  spec.homepage     = 'https://github.com/main-branch/yard_example_runner'
  spec.license      = 'MIT'
  spec.version      = version

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "https://rubydoc.info/gems/#{spec.name}/#{spec.version}/file/CHANGELOG.md"
  spec.metadata['documentation_uri'] = "https://rubydoc.info/gems/#{spec.name}/#{spec.version}"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.3.0'

  spec.add_dependency 'minitest', '~> 6.0'
  spec.add_dependency 'yard', '~> 0.9'

  spec.add_development_dependency 'aruba', '~> 2.3'
  spec.add_development_dependency 'main_branch_shared_rubocop_config', '~> 0.1'
  spec.add_development_dependency 'minitest-matchers_vaccine', '~> 1.1'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'redcarpet', '~> 3.6'
  spec.add_development_dependency 'rspec-expectations', '~> 3.13'
  spec.add_development_dependency 'rubocop', '~> 1.84'
  spec.add_development_dependency 'ruby-lsp', '~> 0.26'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'yardstick', '~> 0.9'
end
