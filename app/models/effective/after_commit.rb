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

      raise("#{name} is useless outside transaction") unless connection.transaction_open?
      raise("#{name} is useless outside transaction") unless connection.current_transaction.joinable?

      after_commit = Effective::AfterCommit.new("#{name}": callback)
      connection.add_transaction_record(after_commit)
    end

  end
end
