# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

# Basic Config info for the application
class Config
  URL_RUBY_VERSION = URI('https://api.github.com/gists/a056aa3cb3a19b7438614d3aab5cbee8')
  FILE_PATH = File.expand_path('./ruby_version.json')
  TWELVE_DAYS = 86_400 * 12

  class << self
    def version_names
      @version_names ||= Config.ruby_versions + Config.eol_ruby_versions.map { |v| "EOL #{v}" }
    end

    def ruby_versions
      @ruby_versions ||= json_parser(cached_config.dig('files', 'ruby_versions.json', 'content'))
    end

    def default_ruby_version
      @default_ruby_version ||= cached_config.dig('files', 'default_ruby_version.txt', 'content') || '3.1'
    end

    def eol_ruby_versions
      @eol_ruby_versions ||= json_parser(cached_config.dig('files', 'eol_ruby_versions.json', 'content'))
    end

    private

    def cached_config
      @cached_config ||= json_parser(file || request || file(expired: false), {})
    end

    def file(expired: true)
      return unless File.exist?(FILE_PATH) && File.readable?(FILE_PATH)
      return unless file_expired? && expired

      File.read(FILE_PATH)
    end

    def file_expired?
      (File.mtime(FILE_PATH) + TWELVE_DAYS) >= Time.now
    end

    def request
      Net::HTTP.get(URL_RUBY_VERSION).tap { |response| File.write(FILE_PATH, response) }
    rescue JSON::ParserError
      '{}'
    end

    def json_parser(content, default = [])
      return default if content.nil?

      JSON.parse(content)
    rescue JSON::ParserError
      default
    end
  end
end
