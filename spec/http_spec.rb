# frozen_string_literal: true

RSpec.describe Kusameter::HTTP::Client do
  def response(status, body, headers = {})
    Struct.new(:code, :body, :headers) do
      def [](name) = headers[name]
    end.new(status.to_s, body, headers)
  end

  it "retries a temporary failure without exposing its token" do
    config = Kusameter::Configuration.new
    config.token = "secret-value"
    replies = [response(503, "unavailable"), response(200, '{"total_count":2}')]
    waits = []
    transport = ->(_uri, request) {
      expect(request["Authorization"]).to eq("Bearer secret-value")
      replies.shift
    }
    client = described_class.new(config, transport:, sleeper: ->(seconds) { waits << seconds })
    expect(client.get("/search/issues", q: "type:issue", per_page: 1)).to eq("total_count" => 2)
    expect(waits).to eq([1])
    expect(config.inspect).not_to include("secret-value")
  end

  it "honors retry-after and rejects waits above the limit" do
    config = Kusameter::Configuration.new
    config.token = "token"
    config.max_rate_limit_wait = 1
    transport = ->(_uri, _request) { response(429, "limited", "retry-after" => "2") }
    client = described_class.new(config, transport:)
    expect { client.get("/search/issues", q: "test") }.to raise_error(Kusameter::RateLimitError)
  end

  it "converts GraphQL not-found errors and never echoes API bodies" do
    config = Kusameter::Configuration.new
    config.token = "secret-value"
    transport = ->(_uri, _request) { response(200, '{"errors":[{"type":"NOT_FOUND","message":"secret-value"}]}') }
    client = described_class.new(config, transport:)
    expect { client.graphql("query", login: "missing") }.to raise_error(Kusameter::UserNotFoundError)
  end
end
