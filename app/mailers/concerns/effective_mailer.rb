# Includes some shared mailer methods for effective_* gem mailers

module EffectiveMailer
  extend ActiveSupport::Concern

  included do
    default from: -> { mailer_settings.mailer_sender }
    layout -> { mailer_settings.mailer_layout }
  end

  protected

  def mailer_admin
    mailer_settings.mailer_admin
  end

  def subject_for(action, default, resource, opts = {})
    mailer_subject = mailer_settings.mailer_subject

    subject = opts[:subject] || opts['subject'] || default

    if mailer_subject.respond_to?(:call)
      subject = self.instance_exec(action, subject, resource, opts, &mailer_subject)
    end

    subject
  end

  def headers_for(resource, opts = {})
    (resource.respond_to?(:log_changes_datatable) ? opts.merge(log: resource) : opts)
  end

  private

  # This returns the top level gem, EffectiveOrders or EffectiveResources
  def mailer_settings
    name = self.class.name.sub('::', '').sub('Mailer', '')

    # If this is in a gem mailer like Effective::OrdersMailer we use constantize
    # Otherwise this could be included in an ApplicationMailer, so we defer to EffectiveResources
    klass = if name.start_with?('Effective')
      name.constantize
    else
      name.safe_constantize || EffectiveResources
    end

    raise('expected mailer settings to respond to mailer_subject') unless klass.respond_to?(:mailer_subject)
    raise('expected mailer settings to respond to mailer_sender') unless klass.respond_to?(:mailer_sender)
    raise('expected mailer settings to respond to mailer_layout') unless klass.respond_to?(:mailer_layout)

    klass
  end

end
