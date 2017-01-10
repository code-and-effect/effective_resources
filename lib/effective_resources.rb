require 'effective_resources/engine'
require 'effective_resources/version'

module EffectiveResources

  # The following are all valid config keys
  mattr_accessor :authorization_method

  def self.setup
    yield self
  end

  def self.authorized?(controller, action, resource)
    if authorization_method.respond_to?(:call) || authorization_method.kind_of?(Symbol)
      raise Effective::AccessDenied.new() unless (controller || self).instance_exec(controller, action, resource, &authorization_method)
    end
    true
  end

end
