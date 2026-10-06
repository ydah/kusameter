# frozen_string_literal: true

module Kusameter
  module Formatters
    class Csv
      HEADER = %w[login from to pull_requests commits issues reviews].freeze

      def call(results, **_options)
        rows = results.map do |result|
          [result.login, result.period.from, result.period.to, result.pull_requests,
           result.commits, result.issues, result.reviews]
        end
        ([HEADER] + rows).map { |row| row.join(",") }.join("\n") + "\n"
      end
    end
  end
end
