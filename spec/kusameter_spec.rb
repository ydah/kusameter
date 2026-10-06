# frozen_string_literal: true

RSpec.describe Kusameter do
  it "splits multi-year periods without overlap" do
    period = Kusameter::Period.new(from: "2024-02-29", to: "2025-03-01")
    expect(period.split.map(&:to_h)).to eq([
      { from: Date.new(2024, 2, 29), to: Date.new(2025, 2, 27) },
      { from: Date.new(2025, 2, 28), to: Date.new(2025, 3, 1) }
    ])
    expect { Kusameter::Period.new(from: "bad", to: "2025-01-01") }.to raise_error(Kusameter::InvalidPeriodError)
  end

  it "filters public repositories by owner and fork status" do
    filter = Kusameter::Filter.new(exclude_own: true, exclude_forks: true, include_orgs: ["Ruby"])
    repo = { "isPrivate" => false, "isFork" => false, "owner" => { "login" => "ruby" } }
    expect(filter.match?(repo, login: "alice")).to be(true)
    expect(filter.match?(repo.merge("isPrivate" => true), login: "alice")).to be(false)
    expect(filter.match?(repo.merge("isFork" => true), login: "alice")).to be(false)
    expect(filter.match?(repo.merge("owner" => { "login" => "alice" }), login: "alice")).to be(false)
  end

  it "merges counts and repository breakdowns across windows" do
    first = Kusameter::Result.new(login: "alice", period: Kusameter::Period.new(from: "2024-01-01", to: "2024-12-31"),
                                  source: :graphql, pull_requests: 1, commits: 2, issues: 3, reviews: 4,
                                  by_repository: [Kusameter::RepositoryStat.new(name_with_owner: "ruby/ruby", pull_requests: 1, commits: 2, issues: 0, reviews: 0)],
                                  warnings: ["Truncated contributions"])
    second = first.with(pull_requests: 2, warnings: [], by_repository: [first.by_repository.first.with(pull_requests: 2)])
    merged = first.merge(second)
    expect(merged.pull_requests).to eq(3)
    expect(merged.by_repository.first.pull_requests).to eq(3)
    expect(merged.warnings).to eq(["Truncated contributions"])
    expect(merged.truncated?).to be(true)
    expect(merged.total).to eq(21)
  end

  it "calculates every GraphQL window and applies the requested period" do
    source = double("source", max_period: :year)
    allow(source).to receive(:fetch) do |login:, period:, filter:|
      expect(login).to eq("alice")
      expect(filter).to be_a(Kusameter::Filter)
      Kusameter::Result.new(login:, period:, source: :graphql, pull_requests: 1, commits: 2,
                            issues: 0, reviews: 0, by_repository: [], warnings: [])
    end
    period = Kusameter::Period.new(from: "2024-01-01", to: "2025-01-01")
    result = Kusameter::Calculator.new(source:).call(login: "alice", period:, filter: Kusameter::Filter.new)
    expect(result.pull_requests).to eq(2)
    expect(result.period).to eq(period)
    expect(source).to have_received(:fetch).twice
  end

  it "hides the configured token and validates unsupported options" do
    config = Kusameter::Configuration.new
    config.token = "secret-value"
    config.api_endpoint = "https://secret-value.example.com"
    expect(config.inspect).not_to include("secret-value")
    expect { Kusameter.stats("alice", source: :invalid) }.to raise_error(Kusameter::ConfigurationError)
    expect { Kusameter.stats("alice", source: :graphql, merged_only: true) }.to raise_error(Kusameter::ConfigurationError)
  end

  it "uses the requested time zone for date boundaries" do
    config = Kusameter::Configuration.new
    config.time_zone = "Asia/Tokyo"
    expect(config.start_of(Date.new(2025, 1, 1))).to eq("2025-01-01T00:00:00+09:00")
    config.time_zone = "+09:00"
    expect(config.start_of(Date.new(2025, 1, 1))).to eq("2025-01-01T00:00:00+09:00")
  end

  it "wires the facade to the selected source for one or more users" do
    source = double("source", max_period: nil)
    allow(source).to receive(:fetch) do |login:, period:, filter:|
      expect(filter).to be_a(Kusameter::Filter)
      Kusameter::Result.new(login:, period:, source: :graphql, pull_requests: 1, commits: 0,
                            issues: 0, reviews: 0, by_repository: [], warnings: [])
    end
    allow(Kusameter::HTTP::Client).to receive(:new).and_return(double("client"))
    allow(Kusameter::Sources::GraphQL).to receive(:new).and_return(source)
    results = Kusameter.stats_for(%w[alice bob], from: "2025-01-01", to: "2025-12-31")
    expect(results.map(&:login)).to eq(%w[alice bob])
    expect(results.map(&:pull_requests)).to eq([1, 1])
  end
end
