# ActsAsTokened
#
# Implements rails 5 has_secure_token
# Extends the find() method to work with tokens instead of ids. Prevents enumeration of this resource.

module ActsAsTokened
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_tokened(options = nil)
      raise 'must respond to token' unless new().respond_to?(:token)

      include ::ActsAsTokened
    end
  end

  included do
    has_secure_token

    extend FinderMethods
  end

  module ClassMethods
    def relation
      super.tap { |relation| relation.extend(FinderMethods) }
    end
  end

  module FinderMethods
    def find(*args)
      return super unless args.length == 1
      return super if block_given?

      find_by_token(args.first) || raise(::ActiveRecord::RecordNotFound.new("Couldn't find #{name} with 'token'=#{args.first}"))
    end
  end

  # Instance Methods
  def to_param
    token
  end

end

