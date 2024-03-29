EffectiveResources.setup do |config|
  # Authorization Method
  #
  # This method is called by all controller actions with the appropriate action and resource
  # If it raises an exception or returns false, an Effective::AccessDenied Error will be raised
  #
  # Use via Proc:
  # Proc.new { |controller, action, resource| authorize!(action, resource) }       # CanCan
  # Proc.new { |controller, action, resource| can?(action, resource) }             # CanCan with skip_authorization_check
  # Proc.new { |controller, action, resource| authorize "#{action}?", resource }   # Pundit
  # Proc.new { |controller, action, resource| current_user.is?(:admin) }           # Custom logic
  #
  # Use via Boolean:
  # config.authorization_method = true  # Always authorized
  # config.authorization_method = false # Always unauthorized
  #
  # Use via Method (probably in your application_controller.rb):
  # config.authorization_method = :my_authorization_method
  # def my_authorization_method(resource, action)
  #   true
  # end
  config.authorization_method = Proc.new { |controller, action, resource| authorize!(action, resource) }

  # Default Submits
  #
  # These default submit actions will be added to each controller
  # and rendered when calling effective_submit(f)
  # based on the controller, and its `submits` if any.
  #
  # Supported values: 'Save', 'Continue', and 'Add New'
  config.default_submits = ['Save', 'Continue', 'Add New']

  # Mailer Settings
  #
  # The default mailer settings for all effective gems
  #
  # Configure the parent class responsible to send e-mails.
  # config.parent_mailer = '::ApplicationMailer'

  # Default deliver method
  # config.deliver_method = :deliver_later

  # Default layout
  # config.mailer_layout = 'effective_mailer_layout'

  # Customize the Subject
  # config.mailer_subject = Proc.new { |action, subject, resource, opts = {}| subject }

  # Default From
  config.mailer_sender = '"Info" <info@example.com>'

  # Default Froms radios collection
  # Used for effective gems email collection. Leave blank to fallback to just the mailer_sender
  config.mailer_froms = ['"Info" <info@example.com>', '"Admin" <admin@example.com>']

  # Send Admin correspondence To
  config.mailer_admin = '"Admin" <admin@example.com>'
end
