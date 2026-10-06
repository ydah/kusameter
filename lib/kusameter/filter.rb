# frozen_string_literal: true

module Kusameter
  Filter = Data.define(:exclude_own, :exclude_forks, :exclude_orgs, :include_orgs, :merged_only) do
    def initialize(exclude_own: false, exclude_forks: false, exclude_orgs: [], include_orgs: [], merged_only: false)
      excluded = Array(exclude_orgs)
      included = Array(include_orgs)
      names = excluded + included
      raise ArgumentError, "invalid repository owner" unless names.all? { |name| name.is_a?(String) && name.match?(/\A[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?\z/) }

      super(exclude_own:, exclude_forks:, exclude_orgs: excluded, include_orgs: included, merged_only:)
    end

    def match?(repo, login:)
      owner = repo.fetch("owner").fetch("login")
      return false if repo.fetch("isPrivate")
      return false if exclude_own && owner.casecmp?(login)
      return false if exclude_forks && repo.fetch("isFork")
      return false if exclude_orgs.any? { |name| owner.casecmp?(name) }
      return false if include_orgs.any? && include_orgs.none? { |name| owner.casecmp?(name) }

      true
    end
  end
end
