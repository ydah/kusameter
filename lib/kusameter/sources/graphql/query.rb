# frozen_string_literal: true

module Kusameter
  module Sources
    class GraphQL
      QUERY = <<~GRAPHQL.freeze
        query($login: String!, $from: DateTime!, $to: DateTime!) {
          user(login: $login) {
            contributionsCollection(from: $from, to: $to) {
              totalCommitContributions
              totalIssueContributions
              totalPullRequestContributions
              totalPullRequestReviewContributions
              commitContributionsByRepository(maxRepositories: 100) {
                repository { ...Repo }
                contributions { totalCount }
              }
              issueContributionsByRepository(maxRepositories: 100) {
                repository { ...Repo }
                contributions { totalCount }
              }
              pullRequestContributionsByRepository(maxRepositories: 100) {
                repository { ...Repo }
                contributions { totalCount }
              }
              pullRequestReviewContributionsByRepository(maxRepositories: 100) {
                repository { ...Repo }
                contributions { totalCount }
              }
            }
          }
        }
        fragment Repo on Repository {
          nameWithOwner
          isPrivate
          isFork
          owner { login }
        }
      GRAPHQL
    end
  end
end
