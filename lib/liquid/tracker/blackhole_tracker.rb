require 'liquid/tracker/base'

module Tracker
  class BlackholeTracker < Base
    def event(obj, topic)
    end

    def down?
      false
    end

    def shutdown
    end
  end
end
