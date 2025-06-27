# frozen_string_literal: true

# Effective Engine concern

module EffectiveGem
  extend ActiveSupport::Concern

  EXCLUDED_GETTERS = [
    :config, :setup, :send_email, :parent_mailer_class,
    :deliver_method, :mailer_layout, :mailer_sender, :mailer_froms, :mailer_admin, :mailer_subject
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
      (@config[namespace] if namespace) || @config[:effective]
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

    def class_name(name, key)
      raise('expected a class name with a ::') unless name.to_s.include?('::')
      raise('expected key to be a symbol') unless key.kind_of?(Symbol)

      namespace = name.to_s.split('::').first.underscore.to_sym
      config(namespace)[(key.to_s.singularize + '_class_name').to_sym] || "Effective::#{key.to_s.singularize.classify}"
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

    def mailer_froms
      config[:mailer_froms].presence || EffectiveResources.mailer_froms
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

      begin
        mailer_class.send(email, *args).send(deliver_method)
      rescue => e
        associated = args.first

        if associated.kind_of?(ActiveRecord::Base)
          EffectiveLogger.error(e.message, associated: associated, details: { email: email }) if defined?(EffectiveLogger)
          ExceptionNotifier.notify_exception(e, data: { email: email, associated_id: associated.id, associated_type: associated.class.name }) if defined?(ExceptionNotifier)
        else
          args_to_s = args.to_s.gsub('<', '').gsub('>', '')
          EffectiveLogger.error(e.message, details: { email: email, args: args_to_s }) if defined?(EffectiveLogger)
          ExceptionNotifier.notify_exception(e, data: { email: email, args: args_to_s }) if defined?(ExceptionNotifier)
        end

        raise(e) unless Rails.env.production? || Rails.env.staging?
      end
    end
  end

end
