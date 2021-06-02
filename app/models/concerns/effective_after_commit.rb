# EffectiveAfterCommit
#
# Execute code after the ActiveRecord transaction has committed
# Inspired by https://github.com/Envek/after_commit_everywhere
#
# This is automatically included into ActiveRecord::Base
#
# after_commit { MyMailer.welcome.deliver_later }

module EffectiveAfterCommit
  extend ActiveSupport::Concern

  module Base
    def after_commit(connection: self.class.connection, &callback)
      Effective::AfterCommit.register_callback(connection: connection, name: __method__, callback: callback, no_tx_action: :execute)
    end

    def before_commit(connection: self.class.connection, &callback)
      raise(NotImplementedError, "#{__method__} works only with Rails 5.0+") if ActiveRecord::VERSION::MAJOR < 5
      Effective::AfterCommit.register_callback(connection: connection, name: __method__, callback: callback, no_tx_action: :warn_and_execute)
    end

    def after_rollback(connection: self.class.connection, &callback)
      raise('expected a block') unless block_given?
      Effective::AfterCommit.register_callback(connection: connection, name: __method__, callback: callback, no_tx_action: :exception)
    end
  end

end
