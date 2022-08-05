module Update
  class LatestRelease
    RELEASES = URI('https://api.github.com/repos/brand-it/alfred-workflow-ruby-and-rails-docs/releases')

    Response = Struct.new(:response, :download_url)

    def call
      Response.new(response, browser_download_url)
    end

    def browser_download_url
      response&.dig('assets')&.find do |a|
        a['name'] == 'Ruby.Rails.API.Docs.alfredworkflow'
      end&.dig('browser_download_url')
    end

    def response
      @response ||= JSON.parse(Net::HTTP.get(RELEASES)).first || {}
    rescue JSON::ParserError
      {}
    end
  end
end
