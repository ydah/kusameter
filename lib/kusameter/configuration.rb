# frozen_string_literal: true

require "time"

module Kusameter
  class Configuration
    ZONE_MUTEX = Mutex.new
    attr_accessor :token, :api_endpoint, :graphql_endpoint, :source, :time_zone,
                  :timeout, :max_retries, :max_rate_limit_wait, :logger

    def initialize
      @token = nil
      @api_endpoint = "https://api.github.com"
      @graphql_endpoint = "https://api.github.com/graphql"
      @source = :graphql
      @time_zone = "UTC"
      @timeout = 30
      @max_retries = 3
      @max_rate_limit_wait = 60
      @logger = nil
    end

    def resolved_token
      value = token || ENV["KUSAMETER_TOKEN"] || ENV["GITHUB_TOKEN"]
      raise ConfigurationError, "GitHub token is required" if value.nil? || value.empty?

      value
    end

    def inspect
      description = "#<#{self.class} token=[FILTERED] api_endpoint=#{api_endpoint.inspect} " \
                    "graphql_endpoint=#{graphql_endpoint.inspect} source=#{source.inspect} time_zone=#{time_zone.inspect}>"
      secret = token || ENV["KUSAMETER_TOKEN"] || ENV["GITHUB_TOKEN"]
      secret && !secret.empty? ? description.gsub(secret, "[FILTERED]") : description
    end

    def today = in_time_zone { |offset| offset ? Time.now.getlocal(offset).to_date : Time.now.to_date }

    def start_of(date)
      in_time_zone { |offset| local_midnight(date, offset).iso8601 }
    end

    def end_of(date)
      following = date + 1
      in_time_zone { |offset| (local_midnight(following, offset) - Rational(1, 1_000_000)).iso8601(6) }
    end

    private

    def local_midnight(date, offset)
      offset ? Time.new(date.year, date.month, date.day, 0, 0, 0, offset) : Time.local(date.year, date.month, date.day)
    end

    def in_time_zone
      zone = time_zone.to_s
      offset = zone.match?(/\A[+-](?:0\d|1[0-4]):[0-5]\d\z/)
      valid = zone == "UTC" || offset ||
              (zone.match?(/\A[A-Za-z_]+(?:\/[A-Za-z_]+)+\z/) && File.file?("/usr/share/zoneinfo/#{zone}"))
      raise ConfigurationError, "invalid time zone" unless valid
      return yield zone if offset

      # ponytail: TZ is process-wide; use a timezone library if concurrent calls need different zones.
      ZONE_MUTEX.synchronize do
        previous = ENV["TZ"]
        ENV["TZ"] = zone
        begin
          yield
        ensure
          previous ? ENV["TZ"] = previous : ENV.delete("TZ")
        end
      end
    end
  end
end
