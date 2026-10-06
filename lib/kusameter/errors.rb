# frozen_string_literal: true

module Kusameter
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class InvalidPeriodError < Error; end
  class AuthenticationError < Error; end
  class UserNotFoundError < Error; end

  class RateLimitError < Error
    attr_reader :reset_at

    def initialize(message = "GitHub API rate limit exceeded", reset_at: nil)
      @reset_at = reset_at
      super(message)
    end
  end

  class APIError < Error
    attr_reader :status, :body

    def initialize(message = "GitHub API error", status: nil, body: nil)
      @status = status
      @body = body
      super(message)
    end
  end
end
