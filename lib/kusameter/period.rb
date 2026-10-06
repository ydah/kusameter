# frozen_string_literal: true

require "date"

module Kusameter
  Period = Data.define(:from, :to) do
    def initialize(from:, to:)
      from = parse_date(from)
      to = parse_date(to)
      raise InvalidPeriodError, "from must be on or before to" if from > to

      super
    end

    def split
      windows = []
      cursor = from
      while cursor <= to
        finish = [cursor.next_year - 1, to].min
        windows << self.class.new(from: cursor, to: finish)
        cursor = finish + 1
      end
      windows
    end

    private

    def parse_date(value)
      case value
      when Date then value
      when Time then value.to_date
      when String then Date.iso8601(value)
      else raise InvalidPeriodError, "date must be a Date, Time, or ISO 8601 string"
      end
    rescue Date::Error
      raise InvalidPeriodError, "invalid ISO 8601 date"
    end
  end
end
