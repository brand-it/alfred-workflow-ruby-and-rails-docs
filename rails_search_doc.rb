# frozen_string_literal: true

require 'json'
require 'net/http'
require_relative 'rails_versions'

# Search Ruby API docs using a given query and version
class RailsSearchDoc
  REMOVE_JAVASCRIPT = 'var search_data = '
  HOST = 'https://api.rubyonrails.org'
  attr_reader :query, :versions

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

  def initialize(versions, query)
    @query = query.downcase.gsub("v#{RailsVersions.new(query).version}", '').strip
    @versions = versions.take(10)
  end

  def results
    @results ||= search_index.select { |i| i[1]&.downcase&.include?(query) || i[2]&.downcase&.include?(query) }
                             .take(50)
                             .map { |i| Response.new(*i) }
  end

  private

  def search_index
    versions.flat_map { |v| download_search_doc(v) }
  end

  def download_search_doc(version)
    return JSON.parse(File.read(file_path(version))) if file_exists?(version)

    post_download_search_doc Net::HTTP.get(search_index_url(version)).gsub(REMOVE_JAVASCRIPT, ''), version
  end

  def file_exists?(version)
    File.exist?(file_path(version)) && File.readable?(file_path(version))
  end

  def post_download_search_doc(response, version)
    JSON.parse(response).dig('index', 'info').tap do |info|
      info.map! { |i| [version] + i }
      File.write(file_path(version), info.to_json)
    end
  rescue JSON::ParserError
    []
  end

  def file_path(version)
    File.expand_path("./#{version}_search_index.json")
  end

  def search_index_url(version)
    URI("#{HOST}/v#{version}/js/search_index.js")
  end
end
