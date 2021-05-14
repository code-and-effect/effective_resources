# EffectiveDeviseUsr
#
# Mark your user model with devise_for then effective_devise_user

module EffectiveDeviseUser
  extend ActiveSupport::Concern

  module Base
    def effective_devise_user
      include ::EffectiveDeviseUser
    end
  end

  included do
    effective_resource do
      encrypted_password      :string
      reset_password_token    :string
      reset_password_sent_at  :datetime
      remember_created_at     :datetime
      sign_in_count           :integer
      current_sign_in_at      :datetime
      last_sign_in_at         :datetime
      current_sign_in_ip      :inet
      last_sign_in_ip         :inet

      # Devise invitable attributes
      invitation_token        :string
      invitation_created_at   :datetime
      invitation_sent_at      :datetime
      invitation_accepted_at  :datetime
      invitation_limit        :integer
      invited_by_type         :string
      invited_by_id           :integer
      invitations_count       :integer

      # Omniauth
      uid                     :string
      provider                :string

      access_token            :string
      refresh_token           :string
      token_expires_at        :datetime

      name                    :string
      avatar_url              :string
    end

    # Devise invitable ignores model validations, so we manually check for duplicate email addresses.
    before_save(if: -> { new_record? && invitation_sent_at.present? }) do
      if email.blank?
        self.errors.add(:email, "can't be blank")
        raise("email can't be blank")
      end

      if self.class.where(email: email.downcase.strip).exists?
        self.errors.add(:email, 'has already been taken')
        raise("email has already been taken")
      end
    end

    # Clear the provider if an oauth signed in user resets password
    before_save(if: -> { persisted? && encrypted_password_changed? }) do
      assign_attributes(provider: nil, access_token: nil, refresh_token: nil, token_expires_at: nil)
    end
  end

  module ClassMethods
    def effective_devise_user?; true; end

    def permitted_sign_up_params # Should contain all fields as per views/users/_sign_up_fields
      raise('please define a self.permitted_sign_up_params')
      [:email, :password, :password_confirmation, :first_name, :last_name, :name, :login]
    end

    def from_omniauth(auth, params)
      invitation_token = (params.presence || {})['invitation_token']

      email = (auth.info.email.presence || "#{auth.uid}@#{auth.provider}.none").downcase
      image = auth.info.image
      name = auth.info.name || auth.dig(:extra, :raw_info, :login)

      user = if invitation_token
        find_by_invitation_token(invitation_token, false) || raise(ActiveRecord::RecordNotFound)
      else
        where(uid: auth.uid).or(where(email: email)).first || self.new()
      end

      user.assign_attributes(
        uid: auth.uid,
        provider: auth.provider,
        email: email,
        avatar_url: image,
        name: name,
        first_name: (auth.info.first_name.presence || name.split(' ').first.presence || 'First'),
        last_name: (auth.info.last_name.presence || name.split(' ').last.presence || 'Last')
      )

      if auth.respond_to?(:credentials)
        user.assign_attributes(
          access_token: auth.credentials.token,
          refresh_token: auth.credentials.refresh_token,
          token_expires_at: Time.zone.at(auth.credentials.expires_at), # We are given integer datetime e.g. '1549394077'
        )
      end

      # Make a password
      user.password = Devise.friendly_token[0, 20] if user.encrypted_password.blank?

      # Devise Invitable
      invitation_token ? user.accept_invitation! : user.save!

      # Devise Confirmable
      user.confirm if user.respond_to?(:confirm)

      user
    end

    # https://github.com/heartcombo/devise/blob/master/lib/devise/models/recoverable.rb#L134
    def send_reset_password_instructions(attributes = {})
      recoverable = find_or_initialize_with_errors(reset_password_keys, attributes, :not_found)
      return recoverable unless recoverable.persisted?

      # Add custom errors and require a confirmation if previous sign in was provider
      if recoverable.provider.present? && attributes[:confirm_new_password].blank?
        recoverable.errors.add(:email, "previous sign in was with #{recoverable.provider}")
        recoverable.errors.add(:confirm_new_password, 'please confirm to proceed')
      end

      recoverable.send_reset_password_instructions if recoverable.errors.blank?
      recoverable
    end

  end

  # EffectiveDeviseUser Instance Methods

  def reinvite!
    invite!
  end

  def active_for_authentication?
    super && (respond_to?(:archived?) ? !archived? : true)
  end

  def inactive_message
    (respond_to?(:archived?) && archived?) ? :archived : super
  end

  # Any password will work in development or mode
  def valid_password?(password)
    Rails.env.development? || Rails.env.staging? || super
  end

  # Send devise & devise_invitable emails via active job
  def send_devise_notification(notification, *args)
    raise('expected args Hash') unless args.respond_to?(:last) && args.last.kind_of?(Hash)

    if defined?(Tenant)
      tenant = Tenant.current || raise('expected a current tenant')
      args.last[:tenant] ||= tenant
    end

    wait = (5 if notification == :invitation_instructions && !Rails.env.test?)

    devise_mailer.send(notification, self, *args).deliver_later(wait: wait)
  end

end
