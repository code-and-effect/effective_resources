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


    # Clear the provider if an oauth signed in user resets password
    before_save(if: -> { persisted? && encrypted_password_changed? }) do
      assign_attributes(provider: nil, access_token: nil, refresh_token: nil, token_expires_at: nil)
    end

    validate(if: -> { email.present? && try(:alternate_email).present? }) do
      errors.add(:alternate_email, 'cannot be the same as email') if email.strip.downcase == alternate_email.strip.downcase
    end

    # Uniqueness validation of emails and alternate emails across all users
    validate(if: -> { respond_to?(:alternate_email) }) do
      records = self.class.where.not(id: id)

      # Validate email uniqueness
      if (value = email.to_s.strip.downcase).present? && !errors.added?(:email, 'has already been taken')
        existing = records.where("email = :value OR alternate_email = :value", value: value)
        errors.add(:email, 'has already been taken') if existing.present?
      end

      # Validate alternate_email uniqueness
      if (value = alternate_email.to_s.strip.downcase).present?
        existing = records.where("email = :value OR alternate_email = :value", value: value)
        errors.add(:alternate_email, 'has already been taken') if existing.present?
      end
    end

    with_options(if: -> { respond_to?(:alternate_email) }) do
      validates :alternate_email, email: true
    end

  end

  module ClassMethods
    def effective_devise_user?; true; end

    def permitted_sign_up_params # Should contain all fields as per views/users/_sign_up_fields
      raise('please define a self.permitted_sign_up_params')
      [:email, :password, :password_confirmation, :first_name, :last_name, :name, :login]
    end

    def filter_parameters
      [
        :encrypted_password,
        :reset_password_token,
        :reset_password_sent_at,
        :remember_created_at,
        :sign_in_count,
        :current_sign_in_at,
        :last_sign_in_at,
        :current_sign_in_ip,
        :last_sign_in_ip,
        :invitation_token,
        :invitation_created_at,
        :invitation_sent_at,
        :invitation_accepted_at,
        :invitation_limit,
        :invited_by_type,
        :invited_by_id,
        :invitations_count,
        :uid,
        :provider,
        :access_token,
        :refresh_token,
        :token_expires_at,
        :avatar_url,
        :roles_mask,
        :confirmation_sent_at,
        :confirmed_at,
        :unconfirmed_email
      ]
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

    # https://github.com/heartcombo/devise/blob/f6e73e5b5c8f519f4be29ac9069c6ed8a2343ce4/lib/devise/models/authenticatable.rb#L276
    def find_first_by_auth_conditions(tainted_conditions, opts = {})
      conditions = devise_parameter_filter.filter(tainted_conditions).merge(opts)

      user = to_adapter.find_first(conditions)
      return user if user.present? && user.persisted?

      to_adapter.find_first(alternate_email: conditions[:email]) if has_alternate_email?
    end

    # https://github.com/heartcombo/devise/blob/f6e73e5b5c8f519f4be29ac9069c6ed8a2343ce4/lib/devise/models/database_authenticatable.rb#L216
    def find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup.presence || {}

      email = conditions.delete(:email).to_s.strip.downcase
      raise "Expected an email condition but got #{conditions} instead" unless email.present?

      if has_alternate_email?
        where(conditions).where('email = :email OR alternate_email = :email', email: email).first
      else
        where(conditions).where(email: email).first
      end
    end

    def has_alternate_email?
      column_names.include?('alternate_email')
    end

    def find_by_any_email(value)
      email = value.to_s.strip.downcase

      if has_alternate_email?
        where(email: email).or(where(alternate_email: email)).first
      else
        where(email: email).first
      end
    end
  end

  # EffectiveDeviseUser Instance Methods

  # The user's to_s when in an email
  def email_to_s
    to_s
  end

  def alternate_email=(value)
    super(value.to_s.strip.downcase.presence)
  end

  # Devise invitable ignores model validations, so we manually check for duplicate email addresses.
  def invite!(invited_by = nil, options = {})
    if new_record?
      value = email.to_s.strip.downcase

      if value.blank?
        errors.add(:email, "can't be blank")
        return false
      end

      if self.class.where(email: value).present?
        errors.add(:email, 'has already been taken')
        return false
      end

      if respond_to?(:alternate_email) && self.class.where(alternate_email: value).present?
        errors.add(:email, 'has already been taken')
        return false
      end
    end

    super
  end

  def reinvite!
    invite!
  end

  def active_for_authentication?
    super && (respond_to?(:archived?) ? !archived? : true)
  end

  # Allow users to sign in even if they have a pending invitation
  def block_from_invitation?
    false
  end

  # This allows the Sign Up form to work for existing users with a pending invitation
  # It assigns the attributes from the sign_up_params, saves the user, accepts the invitation
  # Note that this action skips the invitation_token validation and is therefore insecure.
  def allow_sign_up_from_invitation?
    true
  end

  def inactive_message
    (respond_to?(:archived?) && archived?) ? :archived : super
  end

  # Any password will work in development mode
  def valid_password?(password)
    Rails.env.development? || super
  end

  # Send devise & devise_invitable emails via active job
  def send_devise_notification(notification, *args)
    raise('expected args Hash') unless args.respond_to?(:last) && args.last.kind_of?(Hash)

    if defined?(Tenant)
      tenant = Tenant.current || raise('expected a current tenant')
      args.last[:tenant] ||= tenant
    end

    devise_mailer.send(notification, self, *args).deliver_now
  end

end
