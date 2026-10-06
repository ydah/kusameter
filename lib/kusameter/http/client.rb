# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Kusameter
  module HTTP
    class Client
      TRANSIENT = [502, 503, 504].freeze
      NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED].freeze

      def initialize(configuration, transport: nil, sleeper: Kernel.method(:sleep))
        @configuration = configuration
        @transport = transport || method(:default_transport)
        @sleeper = sleeper
      end

      def graphql(query, variables)
        uri = endpoint(@configuration.graphql_endpoint)
        request = Net::HTTP::Post.new(uri.request_uri, headers)
        request.body = JSON.generate(query:, variables:)
        parse(perform(uri, request), graphql: true)
      end

      def get(path, params = {})
        base = @configuration.api_endpoint.chomp("/")
        uri = endpoint("#{base}#{path}")
        uri.query = URI.encode_www_form(params)
        parse(perform(uri, Net::HTTP::Get.new(uri.request_uri, headers)))
      end

      private

      def endpoint(value)
        uri = URI.parse(value)
        raise ConfigurationError, "API endpoint must use HTTPS" unless uri.is_a?(URI::HTTPS) && uri.host && !uri.userinfo

        uri
      rescue URI::InvalidURIError
        raise ConfigurationError, "invalid API endpoint"
      end

      def headers
        { "Authorization" => "Bearer #{@configuration.resolved_token}",
          "User-Agent" => "kusameter/#{VERSION}",
          "Accept" => "application/vnd.github+json",
          "Content-Type" => "application/json" }
      end

      def default_transport(uri, request)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: @configuration.timeout,
                        read_timeout: @configuration.timeout) { |http| http.request(request) }
      end

      def perform(uri, request)
        retries = 0
        loop do
          response = @transport.call(uri, request)
          status = response.code.to_i
          if rate_limited?(response)
            reset_at, wait = rate_wait(response)
            raise RateLimitError.new(reset_at:) if wait > @configuration.max_rate_limit_wait || retries >= @configuration.max_retries

            @sleeper.call(wait)
          elsif TRANSIENT.include?(status)
            raise APIError.new("GitHub API unavailable", status:) if retries >= @configuration.max_retries

            @sleeper.call(2**retries)
          else
            return response
          end
          retries += 1
        rescue *NETWORK_ERRORS
          raise APIError, "GitHub API connection failed" if retries >= @configuration.max_retries

          @sleeper.call(2**retries)
          retries += 1
        end
      end

      def rate_limited?(response)
        [403, 429].include?(response.code.to_i) &&
          (response.code.to_i == 429 || response["x-ratelimit-remaining"] == "0" || response["retry-after"])
      end

      def rate_wait(response)
        if response["retry-after"]
          wait = [response["retry-after"].to_f, 0].max
          [Time.now + wait, wait]
        elsif response["x-ratelimit-reset"]
          reset_at = Time.at(response["x-ratelimit-reset"].to_i)
          [reset_at, [reset_at - Time.now, 0].max]
        else
          [Time.now, 0]
        end
      end

      def parse(response, graphql: false)
        status = response.code.to_i
        raise AuthenticationError, "GitHub authentication failed" if status == 401
        raise APIError.new("GitHub API returned HTTP #{status}", status:, body: safe_body(response.body)) unless status.between?(200, 299)

        data = JSON.parse(response.body)
        return data unless graphql && data["errors"]&.any?

        raise UserNotFoundError, "GitHub user not found" if data["errors"].any? { |error| error["type"] == "NOT_FOUND" }

        raise APIError, "GitHub GraphQL request failed"
      rescue JSON::ParserError
        raise APIError.new("Invalid GitHub API response", status:)
      end

      def safe_body(body)
        body.to_s.gsub(@configuration.resolved_token, "[FILTERED]")
      end
    end
  end
end
