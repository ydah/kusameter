# frozen_string_literal: true

module Kusameter
  module Sources
    class Search
      class QueryBuilder
        def build(metric:, login:, period:, filter:, owner: nil, owner_type: nil)
          names = [login, owner, *filter.exclude_orgs].compact
          raise ArgumentError, "invalid GitHub login or owner" unless names.all? { |name| name.match?(/\A[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?\z/) }

          range = "#{period.from.iso8601}..#{period.to.iso8601}"
          terms = case metric
                  when :pull_requests then ["type:pr", "author:#{login}", "created:#{range}"]
                  when :issues then ["type:issue", "author:#{login}", "created:#{range}"]
                  when :reviews then ["type:pr", "reviewed-by:#{login}", "-author:#{login}", "created:#{range}"]
                  when :commits then ["author:#{login}", "author-date:#{range}"]
                  else raise ArgumentError, "unknown metric"
                  end
          terms << "is:public"
          terms << "is:merged" if metric == :pull_requests && filter.merged_only
          terms << "-user:#{login}" if filter.exclude_own
          filter.exclude_orgs.each do |name|
            terms.concat(["-org:#{name}", "-user:#{name}"])
          end
          terms << "#{owner_type == "Organization" ? "org" : "user"}:#{owner}" if owner
          terms.join(" ")
        end
      end
    end
  end
end
