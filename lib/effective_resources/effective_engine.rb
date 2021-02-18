# Effective Engine concern

module EffectiveEngine
  extend ActiveSupport::Concern

  included do
    raise("please define a self.config_keys method") unless respond_to?(:config_keys)

    config_keys.each do |key|
      self.class.define_method(key) { config()[key] }
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
        raise("unsupported config keys: #{unsupported}\n supported keys: #{CONFIG_KEYS}")
      end

      true
    end
  end

end
