module Update
  class Available
    VERSION = 'v4.1.0'
    Reaponse = Struct.new(:message, :update_available)

    attr_reader :latest_release

    def initialize(latest_release)
      @latest_release = latest_release
    end

    def call
      if latest_release.response['tag_name'] == VERSION
        Reaponse.new("Already on newest version #{latest_release.response['tag_name']}", false)
      else
        Reaponse.new("New version #{latest_release.response['tag_name']} available", true)
      end
    end
  end
end
