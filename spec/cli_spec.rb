# frozen_string_literal: true

require "stringio"

RSpec.describe Kusameter::CLI do
  let(:period) { Kusameter::Period.new(from: "2025-01-01", to: "2025-12-31") }

  def result(login)
    Kusameter::Result.new(login:, period:, source: :graphql, pull_requests: 2, commits: 3,
                          issues: 4, reviews: 5, warnings: ["Truncated contributions"],
                          by_repository: [Kusameter::RepositoryStat.new(name_with_owner: "ruby/ruby", pull_requests: 2,
                                                                           commits: 3, issues: 4, reviews: 5)])
  end

  def run(*args)
    @stdout = StringIO.new
    @stderr = StringIO.new
    [described_class.new(stdout: @stdout, stderr: @stderr).run(args), @stdout.string, @stderr.string]
  end

  it "prints a repository table and warns on stderr" do
    allow(Kusameter).to receive(:stats) { |login, **_| result(login) }
    code, out, err = run("alice", "--year", "2025", "--by-repo")
    expect(code).to eq(0)
    expect(out).to include("LOGIN", "alice", "ruby/ruby")
    expect(err).to include("Truncated contributions")
    expect(Kusameter).to have_received(:stats).with("alice", hash_including(from: Date.new(2025, 1, 1), to: Date.new(2025, 12, 31)))
  end

  it "writes JSON for one user and CSV for several users" do
    allow(Kusameter).to receive(:stats) { |login, **_| result(login) }
    code, out, = run("alice", "--format", "json")
    expect(code).to eq(0)
    expect(JSON.parse(out).fetch("pull_requests")).to eq(2)
    code, out, = run("alice", "bob", "--format", "csv")
    expect(code).to eq(0)
    expect(out.lines.length).to eq(3)
    expect(out).to include("alice", "bob")
  end

  it "rejects conflicting periods and keeps successful users on partial failure" do
    code, _out, err = run("alice", "--year", "2025", "--from", "2025-01-01")
    expect(code).to eq(2)
    expect(err).to include("--year")
    allow(Kusameter).to receive(:stats) do |login, **_|
      raise Kusameter::UserNotFoundError, "missing" if login == "nobody"

      result(login)
    end
    code, out, err = run("alice", "nobody", "--format", "json")
    expect(code).to eq(5)
    expect(JSON.parse(out).fetch("login")).to eq("alice")
    expect(err).to include("missing")
  end

  it "does not print a token accidentally supplied as input" do
    config = Kusameter::Configuration.new
    config.token = "ghp_secret"
    allow(Kusameter).to receive(:configuration).and_return(config)
    code, _out, err = run("ghp_secret")
    expect(code).to eq(2)
    expect(err).not_to include("ghp_secret")
  end

  it "reports an invalid time zone as an argument error" do
    code, _out, err = run("alice", "--time-zone", "../invalid")
    expect(code).to eq(2)
    expect(err).to include("time zone")
  end

  it "selects quarters and half-years within the requested year" do
    captured = nil
    allow(Kusameter).to receive(:stats) { |login, **options| captured = options; result(login) }
    ranges = {
      "1Q" => [Date.new(2024, 1, 1), Date.new(2024, 3, 31)],
      "2Q" => [Date.new(2024, 4, 1), Date.new(2024, 6, 30)],
      "3Q" => [Date.new(2024, 7, 1), Date.new(2024, 9, 30)],
      "4Q" => [Date.new(2024, 10, 1), Date.new(2024, 12, 31)],
      "H1" => [Date.new(2024, 1, 1), Date.new(2024, 6, 30)],
      "H2" => [Date.new(2024, 7, 1), Date.new(2024, 12, 31)],
      "上期" => [Date.new(2024, 1, 1), Date.new(2024, 6, 30)],
      "下期" => [Date.new(2024, 7, 1), Date.new(2024, 12, 31)]
    }
    ranges.each do |label, (start_date, end_date)|
      code, = run("alice", "--year", "2024", "--period", label)
      expect(code).to eq(0)
      expect(captured.slice(:from, :to)).to eq(from: start_date, to: end_date)
    end
  end

  it "uses the current year for a period without --year" do
    allow(Kusameter.configuration).to receive(:today).and_return(Date.new(2025, 10, 6))
    allow(Kusameter).to receive(:stats) { |login, **_| result(login) }
    code, = run("alice", "--period", "1Q")
    expect(code).to eq(0)
    expect(Kusameter).to have_received(:stats).with("alice", hash_including(from: Date.new(2025, 1, 1), to: Date.new(2025, 3, 31)))
  end

  it "rejects unknown periods and dates combined with a named period" do
    code, _out, err = run("alice", "--period", "5Q")
    expect(code).to eq(2)
    expect(err).to include("period")
    code, _out, err = run("alice", "--period", "1Q", "--from", "2024-01-01")
    expect(code).to eq(2)
    expect(err).to include("--period")
  end
end
