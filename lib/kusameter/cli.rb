# frozen_string_literal: true

require "optparse"

module Kusameter
  class CLI
    def initialize(stdout: $stdout, stderr: $stderr)
      @stdout = stdout
      @stderr = stderr
    end

    def run(args)
      options = { exclude_orgs: [], include_orgs: [] }
      format = "table"
      by_repo = false
      year = nil
      period = nil
      zone = nil
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: kusameter [options] LOGIN [LOGIN ...]"
        opts.on("--from DATE", "Start date") { |value| options[:from] = value }
        opts.on("--to DATE", "End date") { |value| options[:to] = value }
        opts.on("--year YYYY", "Calendar year") { |value| year = value }
        opts.on("--period NAME", "1Q, 2Q, 3Q, 4Q, H1, or H2") { |value| period = value }
        opts.on("--source NAME", "graphql or search") { |value| options[:source] = value.to_sym }
        opts.on("--exclude-own", "Exclude repositories owned by the user") { options[:exclude_own] = true }
        opts.on("--exclude-forks", "Exclude forks") { options[:exclude_forks] = true }
        opts.on("--exclude-org NAME", "Exclude an owner") { |value| options[:exclude_orgs] << value }
        opts.on("--include-org NAME", "Include an owner") { |value| options[:include_orgs] << value }
        opts.on("--merged-only", "Count merged PRs (search only)") { options[:merged_only] = true }
        opts.on("--by-repo", "Show repository breakdown") { by_repo = true }
        opts.on("--format NAME", "table, json, or csv") { |value| format = value }
        opts.on("--time-zone TZ", "Date boundary time zone") { |value| zone = value }
        opts.on("-v", "--version", "Show version") { @stdout.puts(VERSION); return 0 }
        opts.on("-h", "--help", "Show help") { @stdout.puts(opts); return 0 }
      end
      logins = parser.parse(args.dup)
      raise ArgumentError, "at least one LOGIN is required" if logins.empty?
      raise ArgumentError, "--year cannot be combined with --from or --to" if year && (options[:from] || options[:to])
      raise ArgumentError, "--period cannot be combined with --from or --to" if period && (options[:from] || options[:to])
      raise ArgumentError, "invalid year" if year && !year.match?(/\A\d{4}\z/)
      raise ArgumentError, "invalid format" unless %w[table json csv].include?(format)
      raise ArgumentError, "invalid source" if options[:source] && !%i[graphql search].include?(options[:source])
      raise ArgumentError, "--merged-only requires --source search" if options[:merged_only] && (options[:source] || configuration.source) != :search

      if zone
        original_zone = configuration.time_zone
        configuration.time_zone = zone
        begin
          configuration.today
        rescue ConfigurationError => error
          raise ArgumentError, error.message
        end
      end
      if period
        ranges = { "1Q" => [0, 3], "2Q" => [3, 3], "3Q" => [6, 3], "4Q" => [9, 3],
                   "H1" => [0, 6], "H2" => [6, 6], "上期" => [0, 6], "下期" => [6, 6] }
        offset, months = ranges[period.upcase]
        raise ArgumentError, "invalid period" unless offset

        start_date = Date.new(year ? year.to_i : configuration.today.year, 1, 1) >> offset
        options[:from] = start_date
        options[:to] = (start_date >> months) - 1
      elsif year
        options[:from] = Date.new(year.to_i, 1, 1)
        options[:to] = Date.new(year.to_i, 12, 31)
      end
      results = []
      exit_code = 0
      logins.each do |login|
        results << Kusameter.stats(login, **options)
      rescue Error, ArgumentError => error
        exit_code = error_code(error) if exit_code.zero?
        @stderr.puts(redact("#{login}: #{error.message}"))
      end
      unless results.empty?
        formatter = { "table" => Formatters::Table, "json" => Formatters::Json, "csv" => Formatters::Csv }.fetch(format)
        @stdout.print(formatter.new.call(results, by_repo:))
        results.each { |result| result.warnings.each { |warning| @stderr.puts("#{result.login}: #{warning}") } } unless format == "json"
      end
      exit_code
    rescue OptionParser::ParseError, ArgumentError, InvalidPeriodError => error
      @stderr.puts(redact(error.message))
      2
    rescue ConfigurationError, AuthenticationError => error
      @stderr.puts(redact(error.message))
      3
    ensure
      configuration.time_zone = original_zone if original_zone
    end

    private

    def configuration = Kusameter.configuration

    def redact(message)
      secret = configuration.token || ENV["KUSAMETER_TOKEN"] || ENV["GITHUB_TOKEN"]
      secret && !secret.empty? ? message.gsub(secret, "[FILTERED]") : message
    end

    def error_code(error)
      case error
      when InvalidPeriodError, ArgumentError then 2
      when ConfigurationError, AuthenticationError then 3
      when RateLimitError then 4
      when UserNotFoundError then 5
      else 1
      end
    end
  end
end
