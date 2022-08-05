# frozen_string_literal: true

class Gql
  class LatestReleases < Base
    QUERY = <<-GRAPHQL
      {
        repository(name: "alfred-workflow-ruby-and-rails-docs", owner: "brand-it") {
          latestRelease {
            name
            releaseAssets(first: 10) {
              totalCount
              edges {
                node {
                  url
                }
              }
            }
          }
        }
      }
    GRAPHQL

    def body
      { query: QUERY }
    end
  end
end
