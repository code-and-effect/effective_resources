# frozen_string_literal: true

module EffectiveActsAsEmailFormHelper

  def email_form_fields(form, action = nil, skip: true, to: nil, variables: nil, partial: nil)
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

    # These defaults are only used when there is no email_template
    email_defaults = form.object.email_form_defaults(action) unless email_template.present?

    locals = {
      form: form,
      email_to: to,
      email_skip: skip,
      email_action: (action || true),
      email_defaults: email_defaults,
      email_template: email_template,
      email_variables: variables
    }

    render(partial: (partial || 'effective/acts_as_email_form/fields'), locals: locals)
  end

  def mailer_froms_collection(froms: nil)
    froms ||= EffectiveResources.mailer_froms

    froms.map do |from|
      html = content_tag(:span, escape_once(from))
      [from, from, 'data-html': html]
    end
  end

end
