# frozen_string_literal: true

require 'uri'
require 'json'
require 'net/http'

class AutocompleteGem
  def self.get(query)
    uri = URI("https://rubygems.org/api/v1/search/autocomplete?query=#{query}")
    https = https(uri)
    request = Net::HTTP::Get.new(uri)
    https.request(request)
  end

  def self.https(uri)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = true
    end
  end
end
