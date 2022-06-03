# frozen_string_literal: true

require 'json'
require 'net/http'
require_relative 'file_cache'
require_relative 'rails_versions'

# Search Ruby API docs using a given query and version
class RailsSearchDoc
  HOST = 'https://api.rubyonrails.org'
  LIMIT = 100
  REMOVE_JAVASCRIPT = 'var search_data = '
  VERSION_BOOST = 100
  attr_reader :query, :versions, :limit

  # Meth is one hell of a drug it is also short for method in this case
  Response = Struct.new(:version, :meth, :klass, :path, :args, :description) do
    def url
      "#{HOST}/v#{version}/#{path}"
    end

    def title
      return "v#{version} #{meth}#{args}" if meth && args
      return "v#{version} #{meth}" if meth

      "v#{version} #{klass}"
    end

    def description
      self[:description].gsub!(/<\S+>/, '')
      presence(self[:description])
    end

    def klass
      presence(self[:klass])
    end

    def meth
      presence(self[:meth])
    end

    def args
      presence(self[:args])
    end

    def path
      presence(self[:path])
    end

    def presence(str)
      return if str.to_s == ''

      str
    end
  end

  def initialize(query)
    rails_versions = RailsVersions.new(query)
    @query = rails_versions.query
    @versions = rails_versions.results
  end

  def results
    @results ||= FileCache.new(['rails_search_doc_search_index', 'results', versions.join.delete('.'), query]).fetch do
      search_index.select { |i| match?(i) }
                  .sort_by { |i| sorter(i) }
                  .take(LIMIT)
                  .map { |i| Response.new(*i) }
    end
  end

  private

  def match?(item)
    item[1]&.downcase&.include?(query) || item[2]&.downcase&.include?(query)
  end

  def sorter(item)
    rails_versions_score[item.first] + (item[1].length - query.length).abs + (item[5].to_s == '' ? 1 : 0)
  end

  def rails_versions_score
    @rails_versions_score ||= versions.each_with_object(Hash.new(versions.size * VERSION_BOOST))
                                      .with_index do |(version, hash), index|
      hash[version] = index * VERSION_BOOST
    end
  end

  def search_index
    versions.map { |v| Thread.new { download_search_doc(v) } }.each(&:join).flat_map(&:value)
  end

  def download_search_doc(version)
    FileCache.new(['rails_search_doc_search_index', version]).fetch do
      post_download_search_doc Net::HTTP.get(search_index_url(version)).gsub(REMOVE_JAVASCRIPT, ''), version
    end
  end

  def post_download_search_doc(response, version)
    JSON.parse(response).dig('index', 'info').tap do |info|
      info.map! { |i| [version] + i }
    end
  rescue JSON::ParserError
    []
  end

  def search_index_url(version)
    URI("#{HOST}/v#{version}/js/search_index.js")
  end
end
