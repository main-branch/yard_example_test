# frozen_string_literal: true

desc 'Run markdownlint on all Markdown files'
task :markdownlint do
  sh 'npm run lint:md'
end
