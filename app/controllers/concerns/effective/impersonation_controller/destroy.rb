module Effective
  module ImpersonationController
    module Destroy

      def destroy
        # Reset impersonation
        session[:impersonation_user_id] = nil
        session[:impersonation_original_path] = nil

        # Edge case where the current_user is blank. Weird session data.
        if current_user.blank?
          redirect_to(root_path) and return
        end

        # The current_user exists
        @user = current_user.class.find(session[:impersonation_user_id])
        redirect_path = after_destroy_impersonate_path_for(@user)

        expire_data_after_sign_in!
        warden.session_serializer.store(@user, Devise::Mapping.find_scope!(@user))

        redirect_to(redirect_path)
      end

      def after_destroy_impersonate_path_for(user)
        session[:impersonation_original_path].presence || '/admin/users'
      end

    end
  end
end
