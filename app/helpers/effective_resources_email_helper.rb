# frozen_string_literal: true

module EffectiveResourcesEmailHelper
  def mailer_froms_collection(froms: nil)
    froms ||= EffectiveResources.mailer_froms

    froms.map do |from|
      html = content_tag(:span, escape_once(from))
      [from, from, 'data-html': html]
    end
  end

  # acts_as_email_form
  def email_form_fields(form, action = nil, skip: true, skip_link: nil, to: nil, variables: nil, partial: nil)
    raise('expected a form') unless form.respond_to?(:object)

    resource = form.object

    # Intended for acts_as_email_form but sometimes we use a duck typed object to save these fields as well
    unless resource.class.respond_to?(:acts_as_email_form?) || resource.respond_to?("email_form_action=")
      raise('expected an acts_as_email_form resource or one that responds to email_form_action') 
    end

    # Load the template.
    email_template = if action.present? && defined?(EffectiveEmailTemplates)
      action.kind_of?(Effective::EmailTemplate) ? action : Effective::EmailTemplate.where(template_name: action).first!
    end

    # Display link to the admin email template
    skip_link = !request.path.start_with?('/admin/') if skip_link.nil?

    # These defaults are only used when there is no email_template
    # This can't happen right now.
    email_defaults = form.object.email_form_defaults(action) unless email_template.present?

    from = email_template&.from || email_defaults[:from] || EffectiveResources.mailer_froms.first
    subject = email_template&.subject || email_defaults[:subject] || ''
    body = email_template&.body || email_defaults[:body] || ''
    content_type = email_template&.content_type || email_defaults[:content_type] || ''

    locals = {
      form: form,
      email_to: to,
      email_from: from,
      email_subject: subject,
      email_body: body,
      email_content_type: content_type,
      email_skip: skip,
      email_action: (action || true),
      email_template: email_template,
      email_variables: variables,
      email_skip_link: skip_link
    }

    render(partial: (partial || 'effective/acts_as_email_form/fields'), locals: locals)
  end

  # acts_as_email_notification
  def email_notification_fields(form, action, partial: nil, variables: nil)
    raise('expected a form') unless form.respond_to?(:object)

    resource = form.object

    # Intended for acts_as_email_notification
    raise('expected an acts_as_email_notification resource') unless resource.class.respond_to?(:acts_as_email_notification?)

    # Load the template.
    email_template = if action.present? && defined?(EffectiveEmailTemplates)
      action.kind_of?(Effective::EmailTemplate) ? action : Effective::EmailTemplate.where(template_name: action).first!
    end

    raise('expected an Effective::EmailTemplate') unless email_template.kind_of?(Effective::EmailTemplate)

    locals = {
      form: form,

      email_from: email_template.try(:from),
      email_subject: email_template.try(:subject),
      email_body: email_template.try(:body),
      email_cc: email_template.try(:cc),
      email_bcc: email_template.try(:bcc),
      email_content_type: email_template.try(:content_type),

      email_template: email_template,
      email_variables: variables
    }

    render(partial: (partial || 'effective/acts_as_email_notification/fields'), locals: locals)
  end

  def email_message_html?(message)
    message.parts.find { |part| part.content_type.start_with?('text/html') }.present?
  end

  def email_message_plain?(message)
    message.parts.find { |part| part.content_type.start_with?('text/html') }.blank?
  end

  def email_message_body(message)
    html_body = message.parts.find { |part| part.content_type.start_with?('text/html') }.try(:body).to_s
    plain_body = message.parts.find { |part| part.content_type.start_with?('text/plain') }.try(:body).to_s
    message_body = message.body.to_s

    html_body.presence || plain_body.presence || message_body.presence
  end

end
