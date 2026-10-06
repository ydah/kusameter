# frozen_string_literal: true

require "json"

module Kusameter
  module Formatters
    class Json
      def call(results, by_repo: false)
        values = results.map do |result|
          hash = result.to_h
          hash.delete(:by_repository) unless by_repo
          hash
        end
        JSON.pretty_generate(values.length == 1 ? values.first : values) + "\n"
      end
    end
  end
end
