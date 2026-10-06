# frozen_string_literal: true

module Kusameter
  module Sources
    class GraphQL
      FIELDS = {
        pull_requests: %w[pullRequestContributionsByRepository totalPullRequestContributions],
        commits: %w[commitContributionsByRepository totalCommitContributions],
        issues: %w[issueContributionsByRepository totalIssueContributions],
        reviews: %w[pullRequestReviewContributionsByRepository totalPullRequestReviewContributions]
      }.freeze

      def initialize(client:, configuration:)
        @client = client
        @configuration = configuration
      end

      def max_period = :year

      def fetch(login:, period:, filter:)
        variables = { login:, from: @configuration.start_of(period.from), to: @configuration.end_of(period.to) }
        response = @client.graphql(QUERY, variables)
        errors = response["errors"] || []
        raise UserNotFoundError, "GitHub user not found" if errors.any? { |error| error["type"] == "NOT_FOUND" }
        raise APIError, "GitHub GraphQL request failed" if errors.any?

        user = response.dig("data", "user")
        raise UserNotFoundError, "GitHub user not found" unless user

        collection = user.fetch("contributionsCollection")
        counts = {}
        repositories = {}
        warnings = []
        limited = false
        FIELDS.each do |metric, (field, total_field)|
          entries = collection.fetch(field)
          visible = entries.sum { |entry| entry.dig("contributions", "totalCount") }
          if visible < collection.fetch(total_field)
            at_limit = entries.length == 100
            reason = at_limit ? "100 repository limit" : "repository totals differ"
            warnings << "Truncated #{metric} contributions (#{reason})"
            limited ||= at_limit
          end
          counts[metric] = 0
          entries.each do |entry|
            repo = entry.fetch("repository")
            next unless filter.match?(repo, login:)

            count = entry.dig("contributions", "totalCount")
            counts[metric] += count
            name = repo.fetch("nameWithOwner")
            repositories[name] ||= { pull_requests: 0, commits: 0, issues: 0, reviews: 0 }
            repositories[name][metric] += count
          end
        end

        breakdown = repositories.map { |name, values| RepositoryStat.new(name_with_owner: name, **values) }
        result = Result.new(login:, period:, source: :graphql, **counts,
                            by_repository: breakdown.sort_by(&:name_with_owner), warnings:)
        return result unless limited && period.from < period.to

        middle = period.from + ((period.to - period.from).to_i / 2)
        first = Period.new(from: period.from, to: middle)
        second = Period.new(from: middle + 1, to: period.to)
        fetch(login:, period: first, filter:).merge(fetch(login:, period: second, filter:))
      end
    end
  end
end

require_relative "graphql/query"
