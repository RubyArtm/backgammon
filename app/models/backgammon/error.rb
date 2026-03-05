module Backgammon
  class Error < StandardError
    attr_reader :http_status

    def initialize(message = nil, http_status: :unprocessable_entity)
      super(message)
      @http_status = http_status
    end
  end

  class ForbiddenMove < Error
    def initialize(message = nil)
      super(message, http_status: :forbidden)
    end
  end

  class InvalidMove < Error
    def initialize(message = nil)
      super(message, http_status: :unprocessable_entity)
    end
  end
end