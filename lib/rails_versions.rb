# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative 'rails_search_doc'
require_relative 'file_cache'

# Search Ruby API docs using a given query and version
class RailsVersions
  HOST = URI('https://rubygems.org/gems/rails/versions')
  RAILS_VERSION_PATTERN = %r{/gems/rails/versions/(?<version>\d+.\d+.\d|\d+.\d+|\d+)"}.freeze
  VERSION_PATTERN = /(v)(\d+.\d+.\d|\d+.\d+|\d+)/i.freeze
  LIMIT = 10
  attr_reader :version, :prefix, :query

  def initialize(query = '')
    @prefix = query.match(VERSION_PATTERN).to_a[1].to_s
    @version = query.match(VERSION_PATTERN).to_a[2].to_s
    @query = query.gsub("#{prefix}#{version}", '').strip
  end

  def results
    avalable_versions.select { |v| version_matches?(v) }.sort.reverse.take(LIMIT)
  end

  private

  def avalable_versions
    FileCache.new(['rails_avalable_versions', versions.size.to_s]).fetch do
      version_exists = versions.map { |v| Thread.new { rails_doc_exists?(v) } }.each(&:join).flat_map(&:value)
      versions.zip(version_exists).select { |v| v[1] }.map(&:first)
    end
  end

  def version_matches?(value)
    value.start_with?(version) || version == ''
  end

  def rails_doc_exists?(version)
    Net::HTTP.get_response(URI("#{RailsSearchDoc::HOST}/v#{version}/js/search_index.js")).code == '200'
  end

  def versions
    expires_in = 60 * 60 * 24 # 1 day
    @versions ||= FileCache.new('gem_rails_versions', expires_in: expires_in).fetch do
      Net::HTTP.get(HOST).scan(RAILS_VERSION_PATTERN).flatten.uniq.sort.reverse
    end
  end
end
