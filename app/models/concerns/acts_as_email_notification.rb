# ActsAsEmailNotification
# Used for email notification resources that are initialized from an effective_email_template but save their own liquid template content.
# Effective::EventNotification, Effective::PollNotification, Effective::Notification

module ActsAsEmailNotification
  extend ActiveSupport::Concern

  module Base
    def acts_as_email_notification
      include ::ActsAsEmailNotification
    end
  end

  included do
    if respond_to?(:effective_resource)
      effective_resource do
        from              :string
        cc                :string
        bcc               :string

        subject           :string
        body              :text

        content_type      :string
      end
    end

    validates :from, presence: true, email: true
    validates :cc, email_cc: true
    validates :bcc, email_cc: true

    validates :subject, presence: true
    validates :body, presence: true

    validates :content_type, presence: true, inclusion: { in: ['text/plain', 'text/html'] }

    validates :email_template, presence: true

    with_options(if: -> { defined?(EffectiveEmailTemplates) }) do
      validates :body, liquid: true
      validates :subject, liquid: true
    end

    validate(if: -> { email_notification_html? && body.present? }) do
      errors.add(:body, 'expected html tags in body') if email_notification_body_plain?
    end

    validate(if: -> { email_notification_plain? && body.present? }) do
      errors.add(:body, 'unexpected html tags found in body') if email_notification_body_html?
    end

    validate(if: -> { email_notification_subject_template.present? }) do
      if(invalid = email_notification_subject_variables - email_template_variables).present?
        errors.add(:subject, "Invalid variable: #{invalid.to_sentence}")
      end
    end

    validate(if: -> { email_notification_body_template.present? }) do
      if(invalid = email_notification_body_variables - email_template_variables).present?
        errors.add(:body, "Invalid variable: #{invalid.to_sentence}")
      end
    end
  end

  module ClassMethods
    def acts_as_email_notification?; true; end
  end

  # To be overrided
  def email_template
    raise('to be implemented')
  end

  def email_template_variables
    raise('to be implemented')
  end

  def email_notification_params
    { from: from, cc: cc.presence, bcc: bcc.presence, subject: subject, body: body, content_type: content_type }
  end

  def email_notification_html?
    content_type == 'text/html'
  end

  def email_notification_plain?
    content_type == 'text/plain'
  end

  def email_notification_body_html?
    body.present? && (body.include?('</p>') || body.include?('</div>'))
  end

  def email_notification_body_plain?
    body.present? && !(body.include?('</p>') || body.include?('</div>'))
  end

  def email_notification_body_template
    Liquid::Template.parse(body) rescue nil
  end

  def email_notification_subject_template
    Liquid::Template.parse(subject) rescue nil
  end

  def email_notification_body_variables
    template = email_notification_body_template()
    return unless template.present?

    Liquid::ParseTreeVisitor.for(template.root).add_callback_for(Liquid::VariableLookup) do |node|
      [node.name, *node.lookups].join('.')
    end.visit.flatten.uniq.compact
  end

  def email_notification_subject_variables
    template = email_notification_subject_template()
    return unless template.present?

    Liquid::ParseTreeVisitor.for(template.root).add_callback_for(Liquid::VariableLookup) do |node|
      [node.name, *node.lookups].join('.')
    end.visit.flatten.uniq.compact
  end

end
