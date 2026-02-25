<!--
# @markup markdown
# @title How To Contribute
-->

# Contributing to this project

- [Summary](#summary)
- [How to contribute](#how-to-contribute)
- [How to report an issue or request a feature](#how-to-report-an-issue-or-request-a-feature)
- [How to submit a code or documentation change](#how-to-submit-a-code-or-documentation-change)
  - [Commit message guidelines](#commit-message-guidelines)
    - [What does this mean for contributors?](#what-does-this-mean-for-contributors)
    - [What to know about Conventional Commits](#what-to-know-about-conventional-commits)
  - [Create a pull request](#create-a-pull-request)
  - [Get your pull request reviewed](#get-your-pull-request-reviewed)
- [Branch strategy](#branch-strategy)
- [AI-assisted contributions](#ai-assisted-contributions)
- [Coding standards](#coding-standards)
  - [Tests](#tests)
  - [RuboCop](#rubocop)
  - [Markdownlint](#markdownlint)
- [Licensing](#licensing)

## Summary

This document provides guidelines for contributing to this project. These guidelines
do not cover every situation; use your best judgment when contributing.

If you have suggestions for improving these guidelines, please propose changes via a
pull request.

Please also review and adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) when
participating in the project. Governance and maintainer expectations are described in
[GOVERNANCE.md](GOVERNANCE.md).

## How to contribute

You can contribute in the following ways:

1. [Report an issue or request a
   feature](#how-to-report-an-issue-or-request-a-feature)
2. [Submit a code or documentation
   change](#how-to-submit-a-code-or-documentation-change)

## How to report an issue or request a feature

`yard_example_runner` uses [GitHub
Issues](https://docs.github.com/issues/tracking-your-work-with-issues/about-issues)
for issue tracking and feature requests.

To report an issue or request a feature, please [create a `yard_example_runner`
GitHub issue](https://github.com/main-branch/yard_example_runner/issues/new). Fill in
the template as thoroughly as possible to describe the issue or feature request.

## How to submit a code or documentation change

There is a three-step process for submitting code or documentation changes:

1. Commit your changes to a fork of this repository using [Conventional
   Commits](#commit-message-guidelines)
2. [Create a pull request](#create-a-pull-request)
3. [Get your pull request reviewed](#get-your-pull-request-reviewed)

### Commit message guidelines

The `yard_example_runner` project has adopted the [Conventional Commits
standard](https://www.conventionalcommits.org/en/v1.0.0/) for all commit messages.

This structured approach to commit messages allows us to:

- **Automate versioning and releases:** Tools can now automatically determine the
  semantic version bump (patch, minor, major) based on the types of commits merged.
- **Generate accurate changelogs:** We can automatically create and update a
  `CHANGELOG.md` file, providing a clear history of changes for users and
  contributors.
- **Improve commit history readability:** A standardized format makes it easier for
  everyone to understand the nature of changes at a glance.

#### What does this mean for contributors?

All commits to this repository **MUST** adhere to the [Conventional Commits
standard](https://www.conventionalcommits.org/en/v1.0.0/). Commits not adhering to
this standard will cause the CI build to fail. PRs will not be merged if they include
non-conventional commits.

A git `commit-msg` hook can be installed to validate conventional commit messages by
running `bin/setup` in the project root.

#### What to know about Conventional Commits

The simplest conventional commit is in the form `type: description` where `type`
indicates the type of change and `description` is your usual commit message (with
some limitations).

- Common types include: `feat`, `fix`, `docs`, `test`, `refactor`, and `chore`. See
  the full list of supported types in [.commitlintrc.yml](.commitlintrc.yml).
- The description must (1) not start with an upper case letter, (2) be no more than
  100 characters, and (3) not end with punctuation.

Examples of valid commits:

- `feat: add support for asserting raised exceptions in examples`
- `fix: exception thrown when example output contains special characters`
- `docs: add shared context examples to README`

Commits that include breaking changes must include an exclamation mark before the
colon:

- `feat!: renamed YardExampleRunner::Runner to YardExampleRunner::ExampleRunner`

The commit messages will drive how the version is incremented for each release:

- a release containing a **breaking change** will do a **major** version increment
- a release containing a **new feature** will do a **minor** increment
- a release containing **neither a breaking change nor a new feature** will do a
  **patch** version increment

The full conventional commit format is:

```text
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

- `optional body` may include multiple lines of descriptive text limited to 100 chars
  each
- `optional footers` typically use `BREAKING CHANGE: <description>` where description
  should describe the nature of the backward incompatibility.

Use of the `BREAKING CHANGE:` footer flags a backward incompatible change even if it
is not flagged with an exclamation mark after the `type`. Other footers are allowed
but not acted upon.

See [the Conventional Commits
specification](https://www.conventionalcommits.org/en/v1.0.0/) for more details.

### Create a pull request

If you are not familiar with GitHub Pull Requests, please refer to [this
article](https://docs.github.com/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests).

Follow the instructions in the pull request template.

### Get your pull request reviewed

Code review takes place in a GitHub pull request using the [GitHub pull request
review
feature](https://docs.github.com/pull-requests/collaborating-with-pull-requests/getting-started/helping-others-review-your-changes).

Once your pull request is ready for review, request a review from at least one
[maintainer](MAINTAINERS.md) and any other contributors you deem necessary.

During the review process, you may need to make additional commits. Before merging,
your branch must be up to date with `main` and merge cleanly. Keep history focused
and easy to review.

At least one approval from a project maintainer is required before your pull request
can be merged. The maintainer is responsible for ensuring that the pull request meets
[the project's coding standards](#coding-standards).

## Branch strategy

Development happens on feature branches in a fork of this repository. Changes are
merged into `main` of this repository via pull requests. **Never commit directly to
`main` of this repository.** This ensures proper code review, CI validation, and
maintains a clean commit history.

## AI-assisted contributions

AI-assisted contributions are welcome. Please review and apply our [AI
Policy](AI_POLICY.md) before submitting changes. You are responsible for
understanding and verifying any AI-assisted work included in PRs and ensuring it
meets our standards for quality, security, and licensing.

## Coding standards

To ensure high-quality contributions, all pull requests must meet the following
requirements:

### Tests

- All changes must be accompanied by new or modified tests.
- The entire test suite must pass when `bundle exec rake` is run from the project's
  local working copy.

This project uses [Cucumber](https://cucumber.io/) with
[Aruba](https://github.com/cucumber/aruba) for system-level tests. Tests live in the
`features/` directory.

To run the tests:

```bash
bundle exec rake cucumber
```

New and updated public-facing features should be documented in the project's
[README.md](README.md).

### RuboCop

All Ruby code must pass [RuboCop](https://rubocop.org/) static analysis. Violations
will cause the CI build to fail. PRs will not be merged if they include RuboCop
offenses.

To run RuboCop:

```bash
bundle exec rake rubocop
```

### Markdownlint

All Markdown files must pass [markdownlint](https://github.com/DavidAnson/markdownlint)
analysis. Violations will cause the CI build to fail. PRs will not be merged if they
include markdownlint offenses.

To run markdownlint:

```bash
bundle exec rake markdownlint
```

All coding standards checks are run together with the default `rake` command:

```bash
bundle exec rake
```

## Licensing

`yard_example_runner` uses [the MIT
license](https://choosealicense.com/licenses/mit/) as declared in the
[LICENSE](LICENSE.txt) file.
