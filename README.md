<div align="center">
  <h1>🌱 Kusameter</h1>
  <p><strong>Count public GitHub contributions across any date range.</strong></p>
  <p>
    <a href="https://rubygems.org/gems/kusameter"><img src="https://img.shields.io/gem/v/kusameter.svg" alt="RubyGems version"></a>
    <a href="https://github.com/ydah/kusameter/actions/workflows/main.yml"><img src="https://github.com/ydah/kusameter/actions/workflows/main.yml/badge.svg" alt="CI status"></a>
    <img src="https://img.shields.io/badge/Ruby-%E2%89%A5%203.3-CC342D?logo=ruby&amp;logoColor=white" alt="Ruby 3.3 or newer">
    <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
  </p>
  <p>
    <a href="#features">Features</a> ·
    <a href="#installation">Installation</a> ·
    <a href="#quick-start">Quick start</a> ·
    <a href="#cli-reference">CLI reference</a> ·
    <a href="#ruby-api">Ruby API</a>
  </p>
</div>

---

Kusameter measures a GitHub user's contributions to public repositories. Use the CLI for a quick report or the Ruby API to get counts and repository-level data in your own code.

## Features

- Count pull requests, commits, issues, and pull request reviews.
- Select a rolling year, calendar year, quarter, half-year, or custom dates.
- Filter by repository owner or fork status, with an optional repository breakdown.
- Export results as a table, JSON, or CSV; report multiple users in one command.
- Automatically retry GraphQL ranges that reach GitHub's 100-repository limit.

## Installation

Kusameter requires Ruby 3.3 or newer and has no runtime dependencies outside the standard library.

```sh
gem install kusameter
```

Or add it to your Gemfile:

```ruby
gem "kusameter"
```

From a checkout, run `bundle install` and use `bundle exec exe/kusameter` in place of `kusameter`.

## Quick start

Create a [GitHub personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) and set it in your environment. A fine-grained token needs no additional repository permissions to read public repositories. The CLI checks `KUSAMETER_TOKEN` first, then `GITHUB_TOKEN`.

```sh
export KUSAMETER_TOKEN=your_token
kusameter octocat --year 2025 --period 1Q
```

The table shows one row per user and period. For example, an illustrative result looks like this:

```text
LOGIN    PERIOD                  PRS  COMMITS  ISSUES  REVIEWS
octocat  2025-01-01..2025-03-31  8    42       3       6
```

Add `--by-repo` for a repository breakdown in table or JSON output. Use `--format json` or `--format csv` for structured output.

## CLI reference

```sh
kusameter octocat
kusameter octocat --year 2025 --period H1 --by-repo
kusameter octocat --from 2025-04-01 --to 2025-09-30 --exclude-own
kusameter alice bob --year 2025 --format csv > contributions.csv
kusameter octocat --source search --merged-only --format json
```

With no dates, Kusameter counts the year ending today. Quarters use calendar boundaries (`1Q` is January–March), as do half-years (`H1` is January–June). Without `--year`, `--period` uses the current year. Future end dates are capped at today.

| Option | Description |
| --- | --- |
| `--from DATE`, `--to DATE` | Inclusive ISO 8601 dates. Cannot be combined with `--year` or `--period`. |
| `--year YYYY` | Calendar year. |
| `--period NAME` | `1Q`–`4Q`, `H1`/`H2`, or `上期`/`下期`. |
| `--source NAME` | `graphql` (default) or `search`. |
| `--exclude-own`, `--exclude-forks` | Exclude the user's repositories or forks. |
| `--exclude-org NAME`, `--include-org NAME` | Exclude or include an owner; repeatable. |
| `--merged-only` | Count only merged PRs; requires `--source search`. |
| `--by-repo` | Show repository counts in table or JSON output. |
| `--format NAME` | `table` (default), `json`, or `csv`. |
| `--time-zone TZ` | GraphQL date boundary zone, such as `UTC`, `Asia/Tokyo`, or `+09:00`. |
| `-h`, `--help`; `-v`, `--version` | Show help or version. |

Exit codes are `0` for success, `1` for an API or other error, `2` for invalid input, `3` for missing credentials or authentication failure, `4` for a rate limit, and `5` for a missing user. When multiple users are requested, successful results are still printed if another user fails.

## Ruby API

```ruby
require "kusameter"

result = Kusameter.stats("octocat", from: "2025-01-01", to: "2025-12-31", exclude_own: true)

puts result.pull_requests
puts result.commits
puts result.issues
puts result.reviews
puts result.total
result.by_repository.each { |repo| puts "#{repo.name_with_owner}: #{repo.commits} commits" }
puts result.warnings if result.truncated?

results = Kusameter.stats_for(%w[alice bob], from: "2025-01-01", to: "2025-12-31")
```

Dates can be `Date`, `Time`, or ISO 8601 strings. The result also exposes `period`, `source`, `by_repository`, `warnings`, `truncated?`, and `to_h`.

Configure the token, time zone, or request behavior when using the library:

```ruby
Kusameter.configure do |config|
  config.token = ENV.fetch("MY_GITHUB_TOKEN")
  config.source = :graphql
  config.time_zone = "Asia/Tokyo"
  config.timeout = 30
  config.max_retries = 3
  config.max_rate_limit_wait = 60
end
```

For GitHub Enterprise Server, also set `api_endpoint` to `https://HOST/api/v3` and `graphql_endpoint` to `https://HOST/api/graphql`.

## Counting rules and limits

The default GraphQL source follows [GitHub's contribution rules](https://docs.github.com/en/account-and-profile/reference/profile-contributions-reference) and counts only public repositories. Commits must be linked to the user and reach the default branch or `gh-pages`; commits only on a fork do not count. Review contributions follow [GitHub's contribution collection](https://docs.github.com/en/graphql/reference/users), which represents the latest submitted review per reviewed PR.

GraphQL limits each repository-grouped metric to 100 repositories per request. Kusameter divides periods longer than one year into yearly windows. If a window reaches the 100-repository limit and its repository counts fall short of GitHub's totals, Kusameter splits that window by date and retries. It warns if the difference remains, including when a single day exceeds the limit. Filtered counts always come from the repositories GitHub returned.

The optional Search source counts PRs, issues, and commits without the repository breakdown. Its review count is an approximation: it counts reviewed PRs by PR creation date rather than submitted reviews. Search cannot exclude forks and warns when that option is requested or GitHub reports incomplete results. Its requests are spaced by at least two seconds because of its tighter rate limit. Search date filters use GitHub's date query syntax; `time_zone` affects GraphQL boundaries and the default end date.

API rate limits are retried up to `max_retries` when the required wait is within `max_rate_limit_wait`. Otherwise `Kusameter::RateLimitError` exposes `reset_at`.

## Development

```sh
bundle install
bundle exec rake
```

The default Rake task runs the tests, lint checks, RBS validation, and Steep type checking. Tests use fake HTTP responses and do not call GitHub.

## Contributing

Bug reports and pull requests are welcome in the [GitHub repository](https://github.com/ydah/kusameter).

## License

Released under the [MIT License](LICENSE.txt).
