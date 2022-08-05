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
    CURRENT_FILES = Dir['**/*'].map { |f| File.expand_path(f) }
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

      zipfile.write(start_download.body)
      unzip
      cleanup
      Response.new(nil, true, latest_release.response['tag_name'], latest_release.response['html_url'])
    rescue StandardError => e
      Response.new(e.message, false, latest_release.response['tag_name'], latest_release.response['html_url'])
    ensure
      zipfile.close
      zipfile.unlink
    end

    private

    def update_available
      @update_available ||= Available.new(latest_release).call
    end

    def latest_release
      @latest_release ||= LatestRelease.new.call
    end

    def start_download(url = latest_release.download_url, limit = 10)
      raise ArgumentError, 'too many HTTP redirects' if limit.zero?

      url = URI(url) unless url.is_a?(URI)
      https = https(url)
      request = Net::HTTP::Get.new(url)
      https.request(request).then do |response|
        return response if response.is_a?(Net::HTTPSuccess)

        start_download(response['location'], limit - 1)
      end
    end

    def https(uri)
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl = true
      end
    end

    def unzip
      Zip.on_exists_proc = true
      Zip::File.open(zipfile) do |zip_file|
        zip_file.each do |entry|
          @updated_files << "#{ROOT_PATH}/#{entry.name}"
          entry.extract("#{ROOT_PATH}/#{entry.name}")
        end
      end
    end

    def cleanup
      (CURRENT_FILES - @updated_files).each do |file|
        File.rm_rf(file)
      end
    end

    def zipfile
      @zipfile ||= Tempfile.new('alfred-workflow-ruby-and-rails-docs')
    end
  end
end
