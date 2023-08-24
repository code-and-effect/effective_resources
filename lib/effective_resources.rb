# frozen_string_literal: true

require 'effective_resources/engine'
require 'effective_resources/version'
require 'effective_resources/effective_gem'

module EffectiveResources
  MAILER_SUBJECT_PROC = Proc.new { |action, subject, resource, opts = {}| subject }

  def self.config_keys
    [
      :authorization_method, :default_submits,
      :parent_mailer, :deliver_method, :mailer_layout, :mailer_sender, :mailer_admin, :mailer_subject
    ]
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

  # Mailer Settings
  # These serve as the default mailer settings for all effective_* gems
  # They can be overriden on a per-gem basis.
  def self.deliver_method
    return config[:deliver_method] if config[:deliver_method].present?

    rails = Rails.application.config
    (rails.respond_to?(:active_job) && rails.active_job.queue_adapter) ? :deliver_later : :deliver_now
  end

  def self.parent_mailer_class
    return config[:parent_mailer].constantize if config[:parent_mailer].present?
    '::ApplicationMailer'.safe_constantize || 'ActionMailer::Base'.constantize
  end

  def self.mailer_layout
    config[:mailer_layout] || 'effective_mailer_layout'
  end

  def self.mailer_subject
    config[:mailer_subject] || MAILER_SUBJECT_PROC
  end

  def self.mailer_sender
    config[:mailer_sender] || raise('effective resources mailer_sender missing. Add it to config/initializers/effective_resources.rb')
  end

  def self.mailer_admin
    config[:mailer_admin] || raise('effective resources mailer_admin missing. Add it to config/initializers/effective_resources.rb')
  end

  # Utilities

  # This looks up the best class give the name
  # If the Tenant is present, use those classes first.
  def self.best(name)
    klass = if defined?(Tenant)
      ('::' + Tenant.module_name + '::' + name).safe_constantize ||
      ('::' + Tenant.module_name + '::Effective::' + name).safe_constantize
    end

    klass ||= begin
      ('::' + name).safe_constantize ||
      ('::Effective::' + name).safe_constantize
    end

    raise("unable to find best #{name}") if klass.blank?

    klass
  end

  # Used by streaming CSV export in datatables
  def self.with_resource_enumerator(&block)
    raise('expected a block') unless block_given?

    tenant = Tenant.current if defined?(Tenant)

    if tenant
      Enumerator.new do |enumerator|
        Tenant.as(tenant) { yield(enumerator) }
      end
    else
      Enumerator.new { |enumerator| yield(enumerator) }
    end
  end

  def self.truthy?(value)
    if defined?(::ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES)  # Rails <5
      ::ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include?(value)
    else
      ::ActiveRecord::Type::Boolean.new.cast(value)
    end
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

  # https://stackoverflow.com/questions/66103388/attach-activestorage-blob-with-a-different-filename
  def self.clone_blob(blob, options = {})
    raise('expected an ActiveStorage::Blob') unless blob.kind_of?(ActiveStorage::Blob)

    atts = {
      filename: blob.filename,
      byte_size: blob.byte_size,
      checksum: blob.checksum,
      content_type: blob.content_type,
      metadata: blob.metadata,
    }.merge(options)

    service = blob.service
    duplicate = ActiveStorage::Blob.create_before_direct_upload!(**atts)

    case service.class.name
    when 'ActiveStorage::Service::S3Service', 'ActiveStorage::Service::S3NoDeleteService'
      bucket = service.bucket
      object = bucket.object(blob.key)
      object.copy_to(bucket.object(duplicate.key))
    when 'ActiveStorage::Service::DiskService'
      path = service.path_for(blob.key)
      duplicate_path = service.path_for(duplicate.key)
      FileUtils.mkdir_p(File.dirname(duplicate_path))
      FileUtils.ln(path, duplicate_path) if File.exist?(path)
    else
      raise "unknown storage service #{service.class.name}"
    end

    duplicate
  end

  def self.transaction(resource = nil, &block)
    raise('expected a block') unless block_given?

    if resource.respond_to?(:transaction)
      resource.transaction { yield }
    elsif resource.class.respond_to?(:transaction)
      resource.class.transaction { yield }
    else
      ActiveRecord::Base.transaction { yield }
    end

  end

  def self.replace_nested_attributes(attributes)
    attributes.reject { |k, values| truthy?(values[:_destroy]) }.inject({}) do |h, (key, values)|
      h[key] = values.reject { |k, v| k == 'id' || k == '_destroy' }; h
    end
  end

  # effective_translate
  def self.et(resource, attribute = nil)
    if resource.respond_to?(:datatable_name)
      resource.datatable_name
    elsif resource.respond_to?(:model_name) == false # Just a string. Fees will do this
      value = I18n.t(resource)
      raise StandardError.new("Missing translation: #{resource}") if value.include?(resource)
      value
    elsif attribute.blank?
      resource.model_name.human
    elsif resource.respond_to?(:human_attribute_name)
      resource.human_attribute_name(attribute)
    else
      resource.class.human_attribute_name(attribute)
    end
  end

  def self.etd(resource, attribute = nil)
    et(resource, attribute).downcase
  end

  def self.ets(resource, attribute = nil)
    et(resource, attribute).pluralize
  end

  def self.etsd(resource, attribute = nil)
    et(resource, attribute).pluralize.downcase
  end

end
