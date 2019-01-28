module Effective
  class ActionFailed < StandardError
    attr_reader :action, :subject

    def initialize(message = nil, action = nil, subject = nil)
      @message = message
      @action = action
      @subject = subject
    end

    def to_s
      @message || I18n.t(:'unauthorized.default', :default => 'Action Failed')
    end
  end
end
