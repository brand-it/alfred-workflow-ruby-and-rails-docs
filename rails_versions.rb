# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative 'rails_search_doc'

# Search Ruby API docs using a given query and version
class RailsVersions
  HOST = URI('https://rubygems.org/gems/rails/versions')
  RAILS_VERSION_PATTERN = %r{/gems/rails/versions/(?<version>\S+)"}.freeze
  FILE_PATH = File.expand_path('./rails_versions.json')
  SIXTY_DAYS = 86_400 * 60

  attr_reader :query, :version

  def initialize(query)
    @query = query.downcase
    @version = query.match(/v(\S+)/i).to_a[1].to_s
  end

  def results
    versions.select { |v| rails_doc_exists?(v) && version_matches?(v) }.take(10)
  end

  private

  def version_matches?(value)
    value.include?(version) || version == ''
  end

  def rails_doc_exists?(version)
    return cached_versions[version] if cached_versions.key?(version)

    exists = Net::HTTP.get_response(URI("#{RailsSearchDoc::HOST}/v#{version}/")).code == '200'
    (cached_versions[version] = exists).then { save_changes! }
  end

  def cached_versions
    return @cached_versions if @cached_versions
    return @cached_versions = {} if file_expired?

    @cached_versions = load_file
  end

  def load_file
    return {} unless file_exists?

    JSON.parse(File.read(FILE_PATH))
  end

  def save_changes!
    return @cached_versions = nil if load_file.size >= cached_versions.size

    File.write(FILE_PATH, cached_versions.to_json)
  end

  def file_expired?
    !file_exists? || (mtime + SIXTY_DAYS) <= Time.now
  end

  def mtime
    File.mtime(FILE_PATH) if file_exists?
  end

  def file_exists?
    File.exist?(FILE_PATH) && File.readable?(FILE_PATH)
  end

  def versions
    return cached_versions.keys if cached_versions.keys.any?

    @versions ||= Net::HTTP.get(HOST).scan(RAILS_VERSION_PATTERN).flatten.uniq.sort.reverse
  end
end
