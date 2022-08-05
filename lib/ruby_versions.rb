# frozen_string_literal: true

require 'net/http'
require 'uri'
require_relative 'file_cache'

# Search Ruby API docs using a given query and version
class RubyVersions
  HOST = URI('https://rubyapi.org')
  RUBY_VERSION_PATTERN = %r{href="/(\d+.\d+.\d+|\d+.\d+|\d+)"}.freeze
  VERSION_PATTERN = /(v)(\S+)/i.freeze

  attr_reader :version, :prefix, :query

  def initialize(query = '')
    @refix = query.match(VERSION_PATTERN).to_a[1].to_s
    @version = query.match(VERSION_PATTERN).to_a[2].to_s
    @query = query.gsub("#{prefix}#{version}", '').strip
  end

  def results
    @results ||= FileCache.new('ruby_versions').fetch do
      Net::HTTP.get(HOST).scan(RUBY_VERSION_PATTERN).flatten.uniq.sort.reverse
    end.select { |v| v.start_with?(version) }
  end
end
