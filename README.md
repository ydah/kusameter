# Kusameter

Kusameter measures a GitHub user's contributions to public repositories over a date range. It counts pull requests, commits, issues, and pull request reviews through a Ruby API or a CLI.

Ruby 3.3 or later is required. The gem has no runtime dependencies outside Ruby's standard library.

## Install

Add `gem "kusameter"` to your Gemfile, or run `gem install kusameter` after the gem has been published. From a checkout, run `bundle install` and use `bundle exec exe/kusameter`.

Set a GitHub token with access to public repositories. `KUSAMETER_TOKEN` takes precedence over `GITHUB_TOKEN`; a token set through `Kusameter.configure` takes precedence over both. The CLI accepts tokens only through the environment.

```sh
export KUSAMETER_TOKEN=your_token
bundle exec exe/kusameter octocat --year 2025
```

## CLI

```sh
kusameter octocat
kusameter octocat --from 2023-04-01 --to 2026-03-31 --exclude-own
kusameter octocat --year 2025 --exclude-forks --by-repo
kusameter octocat --year 2025 --period 1Q
kusameter octocat --year 2025 --period H1
kusameter alice bob --year 2025 --format csv > contributions.csv
kusameter octocat --source search --merged-only --format json
```

Without dates, the CLI covers the last year through today. `--year YYYY` selects a calendar year. Add `--period` to select a quarter or half-year within that year; without `--year`, it uses the current year. Periods use calendar boundaries: `1Q` is January–March and `H1` is January–June. `--year` and `--period` cannot be combined with `--from` or `--to`. Future end dates are capped at today.

| Option | Meaning |
| --- | --- |
| `--from DATE`, `--to DATE` | Inclusive ISO 8601 dates |
| `--year YYYY` | Calendar year |
| `--period NAME` | `1Q`–`4Q`, `H1`/`H2`, or the aliases `上期`/`下期` |
| `--source graphql\|search` | Data source; GraphQL is the default |
| `--exclude-own`, `--exclude-forks` | Exclude repositories owned by the user or forks |
| `--exclude-org NAME`, `--include-org NAME` | Exclude or include repository owners; repeatable |
| `--merged-only` | Count only merged PRs; requires Search |
| `--by-repo` | Include a repository breakdown in table or JSON output |
| `--format table\|json\|csv` | Output format; table is the default |
| `--time-zone TZ` | Date boundary zone, such as `UTC`, `Asia/Tokyo`, or `+09:00` |
| `-h`, `--help`; `-v`, `--version` | Help or version |

Exit codes are 0 for success, 1 for an API or other error, 2 for invalid input, 3 for missing credentials or authentication failure, 4 for a rate limit, and 5 for a missing user. With multiple users, successful results are still printed if another user fails; the exit code reflects the first failure.

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

`Kusameter.stats` accepts `Date`, `Time`, or ISO 8601 date strings for `from` and `to`. Its result exposes the four counts, `period`, `source`, `by_repository`, `warnings`, `total`, `truncated?`, and `to_h`.

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

GraphQL is the default source. It follows [GitHub's contribution rules](https://docs.github.com/en/account-and-profile/reference/profile-contributions-reference) and counts only public repositories. A commit must be linked to the user and present on the default branch or `gh-pages` to count. Commits that exist only on a fork do not count. GraphQL review contributions reflect [GitHub's contribution collection](https://docs.github.com/en/graphql/reference/users), which represents the latest submitted review per reviewed PR. A range longer than one year is divided into one-year requests and summed.

GraphQL returns at most 100 repositories per metric and request. When a response reaches that limit and its repository counts fall short of the collection totals, Kusameter splits the date range and retries each half. It continues until the counts are complete or the range is a single day. Any remaining difference produces a warning; filtered counts always come from the returned repositories, and `truncated?` reports that warning.

The optional Search source counts PRs, issues, and commits with GitHub Search. Its review metric counts reviewed PRs by PR creation date, so it is an approximation of reviews submitted during the requested period. Search does not provide a repository breakdown and cannot exclude forks; it warns when `exclude_forks` is requested or GitHub reports incomplete results. `merged_only` applies only to the PR metric. Search requests are spaced by at least two seconds to respect its tighter rate limit. Date boundaries for Search use GitHub's date query syntax; `time_zone` controls GraphQL boundaries and the default end date.

API rate limits are retried up to `max_retries` when the required wait does not exceed `max_rate_limit_wait`. Otherwise `Kusameter::RateLimitError` provides `reset_at`. Authentication, missing users, invalid periods, and other API failures raise subclasses of `Kusameter::Error`.

## Development

```sh
bundle install
bundle exec rake
bundle exec rubocop --only Lint
bundle exec rbs validate
bundle exec steep check
```

Tests use fake HTTP responses and do not call GitHub. `bundle exec rake` enforces at least 90% line coverage and checks the public API facade with Steep. The project is licensed under [MIT](LICENSE.txt).
