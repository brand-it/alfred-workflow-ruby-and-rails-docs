# frozen_string_literal: true

require 'json'
require 'net/http'
require_relative 'rails_versions'

# Search Ruby API docs using a given query and version
class RailsSearchDoc
  REMOVE_JAVASCRIPT = 'var search_data = '
  HOST = 'https://api.rubyonrails.org'
  attr_reader :query, :version

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

  def initialize(version, query)
    @query = query.downcase.gsub("v#{RailsVersions.new(query).version}", '').strip
    @version = version
  end

  def results
    @results ||= search_index['info'].select { |v| v[0].downcase.include?(query) || v[1].downcase.include?(query) }
                                     .map { |v| Response.new(version, *v) }
                                     .reject { |v| v.path.nil? }
                                     .sort_by { |r| query == '' ? r.meth : r.meth.to_s.gsub(query, '').size }
                                     .take(10)
  end

  private

  def search_index
    JSON.parse(download_search_doc)['index']
  rescue JSON::ParserError
    { 'info' => [] }
  end

  def download_search_doc
    return File.read(file_path) if File.exist?(file_path) && File.readable?(file_path)

    Net::HTTP.get(search_index_url).gsub(REMOVE_JAVASCRIPT, '').tap { |response| File.write(file_path, response) }
  end

  def file_path
    @file_path ||= File.expand_path("./#{version}_search_index.json")
  end

  def search_index_url
    URI("#{HOST}/v#{version}/js/search_index.js")
  end
end
