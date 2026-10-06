# frozen_string_literal: true

module Kusameter
  module Sources
    class Search
      PATHS = { pull_requests: "/search/issues", issues: "/search/issues",
                reviews: "/search/issues", commits: "/search/commits" }.freeze

      def initialize(client:, interval: 2, sleeper: Kernel.method(:sleep))
        @client = client
        @interval = interval
        @sleeper = sleeper
        @query_builder = QueryBuilder.new
      end

      def max_period = nil

      def fetch(login:, period:, filter:)
        owners = if filter.include_orgs.empty?
                   [[nil, nil]]
                 else
                   filter.include_orgs.uniq { |name| name.downcase }.map do |name|
                     [name, @client.get("/users/#{name}").fetch("type")]
                   end
                 end
        counts = {}
        warnings = ["Search reviews count reviewed PRs by PR creation date, not submitted reviews"]
        warnings << "Search cannot exclude forks; exclude_forks was ignored" if filter.exclude_forks
        requested = false
        PATHS.each do |metric, path|
          counts[metric] = 0
          owners.each do |owner, owner_type|
            @sleeper.call(@interval) if requested && @interval.positive?
            query = @query_builder.build(metric:, login:, period:, filter:, owner:, owner_type:)
            response = @client.get(path, q: query, per_page: 1)
            requested = true
            counts[metric] += response.fetch("total_count")
            warnings << "Search results may be incomplete" if response["incomplete_results"]
          end
        end
        Result.new(login:, period:, source: :search, **counts, by_repository: [], warnings: warnings.uniq)
      end
    end
  end
end

require_relative "search/query_builder"
