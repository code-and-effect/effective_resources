module Effective
  class AfterCommit

    def initialize(**handlers)
      @handlers = handlers
    end

    def has_transactional_callbacks?
      true
    end

    def trigger_transactional_callbacks?
      true
    end

    def before_committed!(*)
      @handlers[:before_commit]&.call
    end

    def committed!(args)
      @handlers[:after_commit]&.call
    end

    def rolledback!(*)
      @handlers[:after_rollback]&.call
    end

    def self.register_callback(connection:, name:, callback:)
      raise ArgumentError, "#{name} expected a block" unless callback

      in_transaction = (connection.transaction_open? && connection.current_transaction.joinable?)

      # Execute immediately when outside transaction
      return callback.call unless in_transaction

      after_commit = Effective::AfterCommit.new("#{name}": callback)
      connection.add_transaction_record(after_commit)
    end

  end
end
