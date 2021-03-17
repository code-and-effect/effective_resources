# Effective Engine concern

module EffectiveGem
  extend ActiveSupport::Concern

  included do
    raise("expected self.config_keys method") unless respond_to?(:config_keys)

    config_keys.each do |key|
      self.singleton_class.define_method(key) { config()[key] }
    end
  end

  module ClassMethods
    def config(namespace = nil)
      namespace ||= Tenant.current if defined?(Tenant)
      @config.dig(namespace) || @config
    end

    def setup(namespace = nil, &block)
      @config ||= ActiveSupport::OrderedOptions.new
      namespace ||= Tenant.current if defined?(Tenant)

      if namespace
        @config[namespace] ||= ActiveSupport::OrderedOptions.new
      end

      yield(config(namespace))

      if(unsupported = (config(namespace).keys - config_keys)).present?
        if unsupported.include?(:authorization_method)
          raise("config.authorization_method has been removed. This gem will call EffectiveResources.authorization_method instead. Please double check the config.authorization_method setting in config/initializers/effective_resources.rb and remove it from this file.")
        end

        raise("unsupported config keys: #{unsupported}\n supported keys: #{config_keys}")
      end

      true
    end
  end

end
