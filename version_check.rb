# frozen_string_literal: true

require 'json'
require 'net/http'
require_relative 'rails_versions'

# Search Ruby API docs using a given query and version
class VersionCheck
  {
    repository(name: "alfred-workflow-ruby-and-rails-docs", owner: "brand-it") {
      latestRelease {
        name
        releaseAssets(first: 10) {
          totalCount
          edges {
            node {
              url
            }
          }
        }
      }
    }
  }
end

require 'uri'
require 'json'
require 'net/http'

class Gql
  class Github
    URI = URI('https://api.github.com/graphql')
    QUERY = <<-GRAPHQL
      {
        repository(name: "alfred-workflow-ruby-and-rails-docs", owner: "brand-it") {
          latestRelease {
            name
            releaseAssets(first: 10) {
              totalCount
              edges {
                node {
                  url
                }
              }
            }
          }
        }
      }
    GRAPHQL

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

    attr_reader :endpoint

    def request
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = { query: QUERY }.to_json

      Response.new(https.request(request)
    end

    def https
      Net::HTTP.new(URI.host, URI.port).tap do |http|
        http.use_ssl = true
      end
    end
  end
