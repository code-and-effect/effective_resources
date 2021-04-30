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

  # Utilities

  def self.truthy?(value)
    if defined?(::ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES)  # Rails <5
      ::ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include?(value)
    else
      ::ActiveRecord::Type::Boolean.new.cast(value)
    end
  end

  def self.deliver_method
    config = Rails.application.config
    (config.respond_to?(:active_job) && config.active_job.queue_adapter) ? :deliver_later : :deliver_now
  end

  def self.advance_date(date, business_days: 1, holidays: [:ca, :observed])
    raise('business_days must be an integer <= 365') unless business_days.kind_of?(Integer) && business_days <= 365

    business_days.times do
      loop do
        date = date + 1.day
        break if business_day?(date, holidays: holidays)
      end
    end

    date
  end

  def self.business_day?(date, holidays: [:ca, :observed])
    require 'holidays' unless defined?(Holidays)
    date.wday != 0 && date.wday != 6 && Holidays.on(date, *holidays).blank?
  end

end
