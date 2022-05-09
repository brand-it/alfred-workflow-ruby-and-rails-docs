# frozen_string_literal: true

require 'uri'
require 'json'
require 'net/http'
require 'base64'
require_relative 'file_cache'
class AutocompleteGem
  attr_reader :query

  def initialize(query)
    @query = query.to_s
  end

  def results
    FileCache.new(['autocomplete_gem', Base64.strict_encode64(query)]).fetch do
      JSON.parse(get(query).body)
    rescue JSON::ParserError
      []
    end
  end

  def get(query)
    uri = URI("https://rubygems.org/api/v1/search/autocomplete?query=#{query}")
    https = https(uri)
    request = Net::HTTP::Get.new(uri)
    https.request(request)
  end

  def https(uri)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = true
    end
  end
end
