# frozen_string_literal: true

require_relative '../file_cache'
require_relative '../ruby_versions'
class Gql
  class RubyAutocomplete < Base
    HOST_URI = URI('https://rubyapi.org/graphql')

    QUERY = <<-GRAPHQL
      query GetAutocompleteResults($query: String!, $version: String = "3.1") {
        autocomplete(query: $query, version: $version) {
          text
          path
        }
      }
    GRAPHQL

    attr_reader :query, :versions

    def initialize(query)
      ruby_version = RubyVersions.new(query)
      @versions = ruby_version.results
      @query = ruby_version.query
    end

    def results
      return @results if @results

      @results = FileCache.new(['ruby_autocomplete', versions.join.delete('.'), query]).fetch do
        versions.map do |version|
          Thread.new do
            post(HOST_URI, body(version)).tap { |r| r.metadata = { version: version } }
          end
        end.each(&:join).map(&:value).flatten.compact
      end
      @results = @results.select(&:success?)
                         .flat_map { |r| collect(r) } || []
    end

    def collect(response)
      response.parsed_body.dig('data', 'autocomplete').map do |result|
        result.merge('version' => response.metadata[:version])
      end
    end

    def body(version)
      {
        query: QUERY,
        variables: { query: query, version: version }
      }
    end
  end
end
