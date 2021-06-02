module Effective
  class AfterCommit

    def initialize(connection:, **handlers)
      @connection = connection
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

    def add_to_transaction(*)
      @connection.add_transaction_record(self)
    end

    def self.register_callback(connection:, name:, no_tx_action:, callback:)
      raise ArgumentError, "#{name} expected a block" unless callback

      unless (connection.transaction_open? && connection.current_transaction.joinable?)
        case no_tx_action
        when :warn_and_execute
          warn "#{name}: No transaction open. Executing callback immediately."
          return callback.call
        when :execute
          return callback.call
        when :exception
          raise("#{name} is useless outside transaction")
        end
      end

      after_commit = Effective::AfterCommit.new(connection: connection, "#{name}": callback)
      connection.add_transaction_record(after_commit)
    end

  end
end
