# frozen_string_literal: true

module EffectiveActsAsEmailFormHelper

  def email_form_fields(form, action = nil, skip: true, variables: nil, partial: nil)
    raise('expected a form') unless form.respond_to?(:object)

    resource = form.object
    raise('expected an acts_as_email_form resource') unless resource.class.respond_to?(:acts_as_email_form?)

    # Load the template.
    email_template = if action.present? && resource.email_form_effective_email_templates?
      Effective::EmailTemplate.where(template_name: action).first!
    end

    # These defaults are only used when there is no email_template
    email_defaults = form.object.email_form_defaults(action)

    locals = {
      form: form,
      email_skip: skip,
      email_action: (action || true),
      email_defaults: email_defaults,
      email_template: email_template,
      email_variables: variables
    }

    render(partial: (partial || 'effective/acts_as_email_form/fields'), locals: locals)
  end

end
