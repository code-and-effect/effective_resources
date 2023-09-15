#
# This is a override to Devise::Mailers::Helpers to make possible to send
# emails to alternate email addresses as well as their main email.
#
# View source: https://github.com/heartcombo/devise/blob/main/lib/devise/mailers/helpers.rb
#
module Devise
  module Mailers
    module Helpers
      def headers_for(action, opts)
        headers = {
          subject: subject_for(action),
          to: __to__(action), # -> This line is the change
          from: mailer_sender(devise_mapping),
          reply_to: mailer_sender(devise_mapping),
          template_path: template_paths,
          template_name: action
        }
        # Give priority to the mailer's default if they exists.
        headers.delete(:from) if default_params[:from]
        headers.delete(:reply_to) if default_params[:reply_to]

        headers.merge!(opts)

        @email = headers[:to]
        headers
      end

      def __to__(action) # Underscore naming to avoid any possible conflicts ever
        if action == :reset_password_instructions
          [resource.email, resource.try(:alternate_email)].compact.uniq
        else
          resource.email
        end
      end
    end
  end
end
