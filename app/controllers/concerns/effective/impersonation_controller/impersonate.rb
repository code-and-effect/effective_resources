module Effective
  module ImpersonationController
    module Impersonate

      def impersonate
        @user = current_user.class.find(params[:id])
        redirect_path = after_impersonate_path_for(@user)

        authorize! :impersonate, @user

        # Impersonate
        session[:impersonation_user_id] = current_user.id
        session[:impersonation_original_path] = request.referer.presence || '/admin/users'

        expire_data_after_sign_in!
        warden.session_serializer.store(@user, Devise::Mapping.find_scope!(@user))

        @user.touch

        redirect_to(redirect_path)
      end

      def after_impersonate_path_for(user)
        try(:dashboard_path) || try(:root_path) || '/'
      end

    end
  end
end
