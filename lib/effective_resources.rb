require 'effective_resources/engine'
require 'effective_resources/version'
require 'effective_resources/effective_gem'

module EffectiveResources

  def self.config_keys
    [:authorization_method, :default_submits]
  end

  include EffectiveGem

  def self.authorized?(controller, action, resource)
    @exceptions ||= [Effective::AccessDenied, (CanCan::AccessDenied if defined?(CanCan)), (Pundit::NotAuthorizedError if defined?(Pundit))].compact

    return !!authorization_method unless authorization_method.respond_to?(:call)
    controller = controller.controller if controller.respond_to?(:controller)

    begin
      !!(controller || self).instance_exec((controller || self), action, resource, &authorization_method)
    rescue *@exceptions
      false
    end
  end

  def self.authorize!(controller, action, resource)
    raise Effective::AccessDenied.new('Access Denied', action, resource) unless authorized?(controller, action, resource)
  end

  def self.default_submits
    (['Save', 'Continue', 'Add New'] & Array(config.default_submits)).inject({}) { |h, v| h[v] = true; h }
  end

end
