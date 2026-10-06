# frozen_string_literal: true

module Kusameter
  class Calculator
    def initialize(source:)
      @source = source
    end

    def call(login:, period:, filter:)
      windows = @source.max_period ? period.split : [period]
      windows.map { |window| @source.fetch(login:, period: window, filter:) }
             .reduce(:merge).with(period:)
    end
  end
end
