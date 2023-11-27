# ActsAsTokened
#
# Implements rails 5 has_secure_token
# Extends the find() method to work with tokens instead of ids. Prevents enumeration of this resource.

module ActsAsTokened
  extend ActiveSupport::Concern

  module Base
    def acts_as_tokened(options = nil)
      include ::ActsAsTokened
    end
  end

  included do
    has_secure_token  # Will always be 24-digits long

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

      reloading = instance_variable_get(:@_effective_reloading)
      reloading ||= self.class.instance_variable_get(:@_effective_reloading)
      reloading ||= klass.instance_variable_get(:@_effective_reloading) if respond_to?(:klass)

      return find_by_id(args.first) if reloading

      find_by_token(args.first) || raise(::ActiveRecord::RecordNotFound.new("Couldn't find #{name} with 'token'=#{args.first}"))
    end
  end

  # Instance Methods
  def to_param
    token if persisted?
  end

  def to_global_id(**params)
    params[:tenant] = Tenant.current if defined?(Tenant)
    GlobalID.new(URI::GID.build(app: Rails.application.config.global_id.app, model_name: model_name, model_id: to_param, params: params))
  end

  def reload(options = nil)
    self.class.instance_variable_set(:@_effective_reloading, true)
    retval = super
    self.class.instance_variable_set(:@_effective_reloading, nil)
    retval
  end

end
