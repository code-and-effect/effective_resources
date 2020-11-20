require 'effective_resources/engine'
require 'effective_resources/version'

module EffectiveResources

  # The following are all valid config keys
  mattr_accessor :authorization_method
  mattr_accessor :default_submits

  def self.setup
    yield self
  end

  def self.authorized?(controller, action, resource)
    @_exceptions ||= [Effective::AccessDenied, (CanCan::AccessDenied if defined?(CanCan)), (Pundit::NotAuthorizedError if defined?(Pundit))].compact

    return !!authorization_method unless authorization_method.respond_to?(:call)
    controller = controller.controller if controller.respond_to?(:controller)

    begin
      !!(controller || self).instance_exec((controller || self), action, resource, &authorization_method)
    rescue *@_exceptions
      false
    end
  end

  def self.authorize!(controller, action, resource)
    raise Effective::AccessDenied.new('Access Denied', action, resource) unless authorized?(controller, action, resource)
  end

  def self.default_submits
    @_default_submits ||= begin
      (['Save', 'Continue', 'Add New'] & Array(@@default_submits)).inject({}) { |h, v| h[v] = true; h }
    end
  end

end
