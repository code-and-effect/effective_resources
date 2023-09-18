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
    before_save(if: -> { new_record? && try(:invitation_sent_at).present? }) do
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

    # Uniqueness validation of emails and alternate emails across all users
    validate(if: -> { respond_to?(:alternate_email) }) do
      records = self.class.where.not(id: self.id) # exclude self
      email_duplicates = records.where("lower(email) = :email OR lower(alternate_email) = :email", email: email.to_s.strip.downcase)
      alternate_email_duplicates = records.where("lower(email) = :alternate_email OR lower(alternate_email) = :alternate_email", alternate_email: alternate_email.to_s.strip.downcase)

      # Check if a uniqueness validation was already performed before triggering the exists query
      if !self.errors.added?(:email, 'has already been taken') && email_duplicates.exists?
        self.errors.add(:email, 'has already been taken')
      end

      # Check if the alternate email is set before triggering the exists query
      if try(:alternate_email).present? && alternate_email_duplicates.exists?
        self.errors.add(:alternate_email, 'has already been taken')
      end
    end

    with_options(if: -> { respond_to?(:alternate_email) }) do
      validates :alternate_email, email: true, allow_blank: true
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
      email = conditions[:email]
      conditions.delete(:email)

      user = to_adapter.find_first(conditions.merge(email: email))
      return user if user.present? && user.persisted?

      to_adapter.find_first(conditions.merge(alternate_email: email)) if respond_to?(:alternate_email)
    end

    # https://github.com/heartcombo/devise/blob/f6e73e5b5c8f519f4be29ac9069c6ed8a2343ce4/lib/devise/models/database_authenticatable.rb#L216
    def find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup.presence || {}
      primary_or_alternate_email = conditions[:email]
      conditions.delete(:email)

      has_alternate_email = 'alternate_email'.in? column_names

      raise "Expected an email #{has_alternate_email ? 'or alternate email' : ''} but got [#{primary_or_alternate_email}] instead" if primary_or_alternate_email.blank?

      query = if has_alternate_email
                "lower(email) = :value OR lower(alternate_email) = :value"
              else
                "lower(email) = :value"
              end

      all
        .where(conditions)
        .where(query, value: primary_or_alternate_email.strip.downcase)
        .first
    end

  end

  # EffectiveDeviseUser Instance Methods

  def alternate_email=(value)
    super(value.to_s.strip.downcase.presence)
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

    devise_mailer.send(notification, self, *args).deliver_now
  end

end
