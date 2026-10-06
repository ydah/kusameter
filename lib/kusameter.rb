# frozen_string_literal: true

require_relative "kusameter/version"
require_relative "kusameter/errors"
require_relative "kusameter/period"
require_relative "kusameter/filter"
require_relative "kusameter/result"
require_relative "kusameter/configuration"
require_relative "kusameter/calculator"
require_relative "kusameter/http/client"
require_relative "kusameter/sources/graphql"
require_relative "kusameter/sources/search"
require_relative "kusameter/formatters/table"
require_relative "kusameter/formatters/json"
require_relative "kusameter/formatters/csv"
require_relative "kusameter/cli"

module Kusameter
  def self.configuration = (@configuration ||= Configuration.new)

  def self.configure
    yield configuration
  end

  def self.stats(login, from: nil, to: nil, source: nil, **filter_options)
    raise ArgumentError, "invalid GitHub login" unless login.is_a?(String) && login.match?(/\A[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?\z/)

    source ||= configuration.source
    raise ConfigurationError, "source must be graphql or search" unless %i[graphql search].include?(source)

    filter = Filter.new(**filter_options)
    raise ConfigurationError, "merged_only requires the search source" if filter.merged_only && source == :graphql

    today = configuration.today
    finish = to ? Period.new(from: to, to: to).to : today
    finish = [finish, today].min
    start = from || (finish.prev_year + 1)
    period = Period.new(from: start, to: finish)
    client = HTTP::Client.new(configuration)
    adapter = source == :graphql ? Sources::GraphQL.new(client:, configuration:) : Sources::Search.new(client:)
    Calculator.new(source: adapter).call(login:, period:, filter:)
  end

  def self.stats_for(logins, **options)
    logins.map { |login| stats(login, **options) }
  end
end
