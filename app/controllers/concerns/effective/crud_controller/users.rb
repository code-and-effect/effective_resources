module Effective
  module CrudController
    module Users

      # If we're impersonating, this is the original user
      def impersonation_user
        return unless current_user.present?
        return unless session[:impersonation_user_id].present?

        @impersonation_user ||= current_user.class.find(session[:impersonation_user_id])
      end

    end
  end
end
