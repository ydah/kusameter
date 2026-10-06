# frozen_string_literal: true

module Kusameter
  RepositoryStat = Data.define(:name_with_owner, :pull_requests, :commits, :issues, :reviews) do
    def to_h = { name_with_owner:, pull_requests:, commits:, issues:, reviews: }
  end

  Result = Data.define(:login, :period, :source, :pull_requests, :commits, :issues, :reviews, :by_repository, :warnings) do
    def merge(other)
      raise ArgumentError, "cannot merge different users or sources" unless login == other.login && source == other.source

      repos = (by_repository + other.by_repository).group_by { |repo| repo.name_with_owner.downcase }.values.map do |items|
        RepositoryStat.new(name_with_owner: items.first.name_with_owner,
                           **count_keys.to_h { |key| [key, items.sum(&key)] })
      end
      self.class.new(login:, source:, period: Period.new(from: [period.from, other.period.from].min,
                                                         to: [period.to, other.period.to].max),
                     **count_keys.to_h { |key| [key, public_send(key) + other.public_send(key)] },
                     by_repository: repos.sort_by(&:name_with_owner), warnings: (warnings + other.warnings).uniq)
    end

    def total = count_keys.sum { |key| public_send(key) }
    def truncated? = warnings.any? { |warning| warning.start_with?("Truncated") }

    def to_h
      { login:, period: { from: period.from.iso8601, to: period.to.iso8601 }, source:,
        **count_keys.to_h { |key| [key, public_send(key)] },
        by_repository: by_repository.map(&:to_h), warnings: }
    end

    private

    def count_keys = %i[pull_requests commits issues reviews]
  end
end
