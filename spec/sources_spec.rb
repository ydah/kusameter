# frozen_string_literal: true

RSpec.describe "GitHub sources" do
  let(:period) { Kusameter::Period.new(from: "2025-01-01", to: "2025-12-31") }

  def repo(name, private: false, fork: false)
    { "nameWithOwner" => name, "isPrivate" => private, "isFork" => fork,
      "owner" => { "login" => name.split("/").first } }
  end

  def commit_collection(numbers, total:)
    entries = numbers.map do |number|
      { "repository" => repo("ruby/repo#{number}"), "contributions" => { "totalCount" => 1 } }
    end
    { "totalCommitContributions" => total, "commitContributionsByRepository" => entries,
      "totalIssueContributions" => 0, "issueContributionsByRepository" => [],
      "totalPullRequestContributions" => 0, "pullRequestContributionsByRepository" => [],
      "totalPullRequestReviewContributions" => 0, "pullRequestReviewContributionsByRepository" => [] }
  end

  it "counts public GraphQL contributions and detects omitted repositories" do
    public_repo = repo("ruby/ruby")
    private_repo = repo("alice/private", private: true)
    entry = ->(repository, count) { { "repository" => repository, "contributions" => { "totalCount" => count } } }
    collection = {
      "totalPullRequestContributions" => 6,
      "pullRequestContributionsByRepository" => [entry.call(public_repo, 2), entry.call(private_repo, 3)],
      "totalCommitContributions" => 4,
      "commitContributionsByRepository" => [entry.call(public_repo, 4)],
      "totalIssueContributions" => 1,
      "issueContributionsByRepository" => [entry.call(public_repo, 1)],
      "totalPullRequestReviewContributions" => 0,
      "pullRequestReviewContributionsByRepository" => []
    }
    client = double("client")
    allow(client).to receive(:graphql).and_return({ "data" => { "user" => { "contributionsCollection" => collection } } })
    result = Kusameter::Sources::GraphQL.new(client:, configuration: Kusameter::Configuration.new)
                                      .fetch(login: "alice", period:, filter: Kusameter::Filter.new)
    expect(result.pull_requests).to eq(2)
    expect(result.commits).to eq(4)
    expect(result.by_repository.map(&:name_with_owner)).to eq(["ruby/ruby"])
    expect(result.truncated?).to be(true)
    expect(result.warnings).to include("Truncated pull_requests contributions (repository totals differ)")
    expect(client).to have_received(:graphql).once
  end

  it "splits truncated GraphQL ranges until all repositories are counted" do
    slices = { [1, 4] => [(1..100), 103], [1, 2] => [(1..100), 101],
               [1, 1] => [(1..2), 2], [2, 2] => [(3..101), 99], [3, 4] => [(102..103), 2] }
    dates = []
    client = double("client")
    allow(client).to receive(:graphql) do |_query, variables|
      days = [Date.iso8601(variables.fetch(:from)).day, Date.iso8601(variables.fetch(:to)).day]
      dates << days
      repositories, total = slices.fetch(days)
      { "data" => { "user" => { "contributionsCollection" => commit_collection(repositories, total:) } } }
    end

    result = Kusameter::Sources::GraphQL.new(client:, configuration: Kusameter::Configuration.new)
                                      .fetch(login: "alice", period: Kusameter::Period.new(from: "2025-01-01", to: "2025-01-04"),
                                             filter: Kusameter::Filter.new)

    expect(result.commits).to eq(103)
    expect(result.by_repository.length).to eq(103)
    expect(result.warnings).to be_empty
    expect(dates).to eq([[1, 4], [1, 2], [1, 1], [2, 2], [3, 4]])
  end

  it "keeps the warning when a single day exceeds the repository limit" do
    collection = commit_collection(1..100, total: 101)
    client = double("client", graphql: { "data" => { "user" => { "contributionsCollection" => collection } } })

    result = Kusameter::Sources::GraphQL.new(client:, configuration: Kusameter::Configuration.new)
                                      .fetch(login: "alice", period: Kusameter::Period.new(from: "2025-01-01", to: "2025-01-01"),
                                             filter: Kusameter::Filter.new)

    expect(result.commits).to eq(100)
    expect(result.truncated?).to be(true)
    expect(client).to have_received(:graphql).once
  end

  it "rejects a missing GraphQL user" do
    client = double("client", graphql: { "data" => { "user" => nil } })
    source = Kusameter::Sources::GraphQL.new(client:, configuration: Kusameter::Configuration.new)
    expect { source.fetch(login: "ghp_secret", period:, filter: Kusameter::Filter.new) }
      .to raise_error(Kusameter::UserNotFoundError) { |error| expect(error.message).not_to include("ghp_secret") }
  end

  it "builds Search queries and reports approximate review counts" do
    calls = []
    client = double("client")
    allow(client).to receive(:get) do |path, params|
      calls << [path, params]
      path == "/users/ruby" ? { "type" => "Organization" } :
        { "total_count" => 2, "incomplete_results" => path == "/search/commits" }
    end
    filter = Kusameter::Filter.new(exclude_own: true, exclude_forks: true,
                                   include_orgs: ["ruby"], merged_only: true)
    result = Kusameter::Sources::Search.new(client:, interval: 0)
                                     .fetch(login: "alice", period:, filter:)
    expect(calls.length).to eq(5)
    expect(calls[1].first).to eq("/search/issues")
    expect(calls[1].last.fetch(:q)).to include("type:pr", "is:merged", "-user:alice", "org:ruby")
    expect(calls.last.first).to eq("/search/commits")
    expect(calls.last.last.fetch(:q)).to include("author-date:2025-01-01..2025-12-31")
    expect(result.pull_requests).to eq(2)
    expect(result.by_repository).to be_empty
    expect(result.warnings.join).to include("reviewed PRs", "fork", "incomplete")
  end
end
