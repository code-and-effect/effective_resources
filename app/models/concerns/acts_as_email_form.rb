# ActsAsEmailForm
# Adds an email_form_skip, email_form_from, email_form_subject, email_form_body attr_accessors
# And some helpful methods to render and validate a Email to Send form
# That should work with or without effective_email_templates to send an email on a model

module ActsAsEmailForm
  extend ActiveSupport::Concern

  module Base
    def acts_as_email_form
      include ::ActsAsEmailForm
    end
  end

  included do
    # Yes, we are submitting an email form
    attr_accessor :email_form_action

    # Skip sending the email entirely
    attr_accessor :email_form_skip

    # The email From / Subject / Body fields
    attr_accessor :email_form_from
    attr_accessor :email_form_subject
    attr_accessor :email_form_body

    if respond_to?(:effective_resource)
      effective_resource do
        email_form_action      :string, permitted: true
        email_form_skip        :boolean, permitted: true

        email_form_from        :string, permitted: true
        email_form_subject     :string, permitted: true
        email_form_body        :text, permitted: true
      end
    end

    with_options(if: -> { email_form_action.present? && !email_form_skip? }) do
      validates :email_form_from, presence: true
      validates :email_form_subject, presence: true
      validates :email_form_body, presence: true

      validate(unless: -> { email_form_from.blank? }) do
        errors.add(:email_form_from, 'must be a valid email address') unless email_form_from.include?('@')
      end
    end

    with_options(if: -> { defined?(EffectiveEmailTemplates) }) do
      validates :email_form_subject, liquid: true
      validates :email_form_body, liquid: true
    end
  end

  module ClassMethods
    def acts_as_email_form?; true; end
  end

  # Instance methods
  def email_form_params
    { from: email_form_from, subject: email_form_subject, body: email_form_body }.compact
  end

  def email_form_skip?
    EffectiveResources.truthy?(email_form_skip)
  end

  # Only considered when not using an effective email template
  def email_form_defaults(action)
    { from: nil, subject: nil, body: nil, content_type: 'text/plain' }
  end

end
