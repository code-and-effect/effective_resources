# Effective Engine concern

module EffectiveGem
  extend ActiveSupport::Concern

  EXCLUDED_GETTERS = [
    :config, :setup, :send_email, :parent_mailer_class,
    :deliver_method, :mailer_layout, :mailer_sender, :mailer_admin, :mailer_subject
  ]

  included do
    raise("expected self.config_keys method") unless respond_to?(:config_keys)

    # Define getters
    (config_keys - EXCLUDED_GETTERS).each do |key|
      self.singleton_class.define_method(key) { config()[key] }
    end

    # Define setters
    config_keys.each do |key|
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

    # Mailer Settings
    # These methods are intended to flow through to the default EffectiveResources settings
    def parent_mailer_class
      config[:parent_mailer].presence&.constantize || EffectiveResources.parent_mailer_class
    end

    def deliver_method
      config[:deliver_method].presence || EffectiveResources.deliver_method
    end

    def mailer_layout
      config[:mailer_layout].presence || EffectiveResources.mailer_layout
    end

    def mailer_sender
      config[:mailer_sender].presence || EffectiveResources.mailer_sender
    end

    def mailer_admin
      config[:mailer_admin].presence || EffectiveResources.mailer_admin
    end

    def mailer_subject
      config[:mailer_subject].presence || EffectiveResources.mailer_subject
    end

    def send_email(email, *args)
      raise('gem does not respond to mailer_class') unless respond_to?(:mailer_class)
      raise('expected args to be an Array') unless args.kind_of?(Array)

      mailer_class.send(email, *args).send(deliver_method)
    end

  end

end
