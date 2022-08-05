# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'tempfile'
require 'zip'
require_relative 'available'
require_relative 'latest_release'

module Update
  class Download
    RELEASES = URI('https://api.github.com/repos/brand-it/alfred-workflow-ruby-and-rails-docs/releases')
    CURRENT_FILES = Dir['**/*']
    ROOT_PATH = File.expand_path('./')

    Response = Struct.new(:message, :success, :version, :url)

    attr_reader :updated_files

    def initialize
      @updated_files = []
    end

    def call
      unless update_available.update_available
        return Response.new(
          update_available.message, false, latest_release.response['tag_name'], latest_release.response['html_url']
        )
      end

      start_download
      unzip
      cleanup
      Response.new(nil, true, latest_release.response['tag_name'], latest_release.response['html_url'])
    rescue StandardError => e
      Response.new(e.message, true, latest_release.response['tag_name'], latest_release.response['html_url'])
    end

    private

    def update_available
      @update_available ||= Available.new(latest_release).call
    end

    def latest_release
      @latest_release ||= LatestRelease.new.call
    end

    def start_download
      Net::HTTP.start(gem.server.host, gem.server.port, use_ssl: gem.server.is_a?(URI::HTTPS)) do |http|
        request = Net::HTTP::Get.new gem.download_path
        http.request request do |response|
          response.read_body do |chunk|
            zipfile.write(chunk)
          end
        end
      end
    ensure
      zipfile.close
    end

    def unzip
      Zip.on_exists_proc = true
      Zip::File.open(zipfile) do |zip_file|
        zip_file.each do |entry|
          @updated_files << entry.name
          entry.extract(ROOT_PATH)
        end
      end
    end

    def cleanup
      (CURRENT_FILES - @updated_files).each do |file|
        FileUtils.rm_rf(file)
      end
    end

    def zipfile
      @zipfile ||= Tempfile.new('alfred-workflow-ruby-and-rails-docs')
    end

    def browser_download_uri
      url = latest_release&.dig('assets')&.find do |a|
        a['name'] == 'Ruby.Rails.API.Docs.alfredworkflow'
      end&.dig('browser_download_url')
      URI(url) if url
    end
  end
end
