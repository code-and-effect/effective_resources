# frozen_string_literal: true

module EffectiveActsAsEmailFormHelper

  def email_form_fields(form, action = nil, skip: true, to: nil, variables: nil, partial: nil)
    raise('expected a form') unless form.respond_to?(:object)

    resource = form.object
    raise('expected an acts_as_email_form resource') unless resource.class.respond_to?(:acts_as_email_form?)

    # Load the template.
    email_template = if action.present? && defined?(EffectiveEmailTemplates)
      action.kind_of?(Effective::EmailTemplate) ? action : Effective::EmailTemplate.where(template_name: action).first!
    end

    if email_template.present?
      resource.email_form_from ||= email_template.from
      resource.email_form_subject ||= email_template.subject
      resource.email_form_body ||= email_template.body
    else
      defaults = form.object.email_form_defaults(action)

      resource.email_form_from ||= defaults[:from]
      resource.email_form_subject ||= defaults[:subject]
      resource.email_form_body ||= defaults[:body]
    end

    resource.email_form_from ||= EffectiveResources.mailer_froms.first

    locals = {
      form: form,
      email_to: to,
      email_skip: skip,
      email_action: (action || true),
      email_template: email_template,
      email_variables: variables
    }

    render(partial: (partial || 'effective/acts_as_email_form/fields'), locals: locals)
  end

end
