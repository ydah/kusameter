# frozen_string_literal: true

module Kusameter
  module Formatters
    class Table
      def call(results, by_repo: false)
        rows = results.map do |result|
          [result.login, "#{result.period.from}..#{result.period.to}", result.pull_requests,
           result.commits, result.issues, result.reviews].map(&:to_s)
        end
        lines = render(%w[LOGIN PERIOD PRS COMMITS ISSUES REVIEWS], rows)
        if by_repo
          results.each do |result|
            next if result.by_repository.empty?

            detail = result.by_repository.map do |repo|
              [repo.name_with_owner, repo.pull_requests, repo.commits, repo.issues, repo.reviews].map(&:to_s)
            end
            lines << "\n#{result.login} repositories:"
            lines.concat(render(%w[REPOSITORY PRS COMMITS ISSUES REVIEWS], detail))
          end
        end
        lines.join("\n") + "\n"
      end

      private

      def render(header, rows)
        widths = header.each_index.map { |index| ([header[index]] + rows.map { |row| row[index] }).map(&:length).max }
        ([header] + rows).map do |row|
          row.each_with_index.map { |value, index| value.ljust(widths[index]) }.join("  ").rstrip
        end
      end
    end
  end
end
