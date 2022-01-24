# Effective Engine concern

module EffectiveGem
  extend ActiveSupport::Concern

  included do
    raise("expected self.config_keys method") unless respond_to?(:config_keys)

    config_keys.each do |key|
      self.singleton_class.define_method(key) { config()[key] }
      self.singleton_class.define_method("#{key}=") { |value| config()[key] = value }
    end
  end

  module ClassMethods
    def config(namespace = nil)
      namespace ||= Tenant.current if defined?(Tenant)
      @config.dig(namespace) || @config.dig(:effective)
    end

    def setup(namespace = nil, &block)
      @config ||= ActiveSupport::OrderedOptions.new

      namespace ||= Tenant.current if defined?(Tenant)
      namespace ||= :effective

      @config[namespace] ||= ActiveSupport::OrderedOptions.new

      yield(config(namespace))

      if(unsupported = (config(namespace).keys - config_keys)).present?
        if unsupported.include?(:authorization_method)
          raise("config.authorization_method has been removed. This gem will call EffectiveResources.authorization_method instead. Please double check the config.authorization_method setting in config/initializers/effective_resources.rb and remove it from this file.")
        end

        raise("unsupported config keys: #{unsupported}\n supported keys: #{config_keys}")
      end

      true
    end

    # This is included into every gem
    # The gem may not have a mailer or use effective email templates
    def send_email(email, *args)
      raise('gem does not respond to mailer_class') unless respond_to?(:mailer_class)
      raise('expected args to be an Array') unless args.kind_of?(Array)

      mailer_class.send(email, *args).send(EffectiveResources.deliver_method)
    end

  end

end
