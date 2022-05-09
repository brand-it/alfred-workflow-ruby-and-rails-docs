# frozen_string_literal: true

require 'uri'
require 'json'
require 'net/http'

class Gql
  class Base
    Response = Struct.new(:http, :metadata) do
      def success?
        http.is_a?(Net::HTTPSuccess)
      end

      def body
        @body ||= http.read_body
      end

      def metadata
        self[:metadata] || {}
      end

      def parsed_body
        return {} if body.nil?

        @parsed_body ||= JSON.parse(body)
      rescue JSON::ParserError
        nil
      end
    end

    def post(host, body)
      request = Net::HTTP::Post.new(host)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json

      Response.new https(host).request(request)
    end

    def https(host)
      Net::HTTP.new(host.host, host.port).tap do |http|
        http.use_ssl = true
      end
    end
  end
end
require_relative 'latest_releases'
require_relative 'ruby_autocomplete'
