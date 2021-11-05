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
    when 'ActiveStorage::Service::S3Service'
      bucket = service.bucket
      object = bucket.object(blob.key)
      object.copy_to(bucket.object(duplicate.key))
    when 'ActiveStorage::Service::DiskService'
      path = service.path_for(blob.key)
      duplicate_path = service.path_for(duplicate.key)
      FileUtils.mkdir_p(File.dirname(duplicate_path))
      FileUtils.ln(path, duplicate_path) if File.exists?(path)
    else
      raise "unknown storage service #{service.class.name}"
    end

    duplicate
  end

end
