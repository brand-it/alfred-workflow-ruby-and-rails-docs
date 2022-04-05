# frozen_string_literal: true

require 'uri'
require 'json'
require 'net/http'

class Gql
  class RubyApi
    QUERY = <<-GRAPHQL
      query GetAutocompleteResults($query: String!, $version: String = "3.1") {
        autocomplete(query: $query, version: $version) {
          text
          path
        }
      }
    GRAPHQL
    HOST_URI = URI('https://rubyapi.org/graphql')

    Response = Struct.new(:http) do
      def success?
        http.is_a?(Net::HTTPSuccess)
      end

      def body
        @body ||= http.read_body
      end

      def parsed_body
        return {} if body.nil?

        @parsed_body ||= JSON.parse(body)
      rescue JSON::ParserError
        nil
      end
    end

    attr_reader :query, :version

    def initialize(version, query)
      @version = version
      @query = query
    end

    def request
      request = Net::HTTP::Post.new(HOST_URI)
      request['Content-Type'] = 'application/json'
      request.body = { query: QUERY, variables: { query: query, version: version } }.to_json

      Response.new https.request(request)
    end

    def https
      Net::HTTP.new(HOST_URI.host, HOST_URI.port).tap do |http|
        http.use_ssl = true
      end
    end
  end
end
