module Effective
  module ImpersonationController
    module Impersonate
      extend ActiveSupport::Concern

      included do
        before_action :delete_blank_password_params, only: [:update]
      end

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

      private

      def delete_blank_password_params
        if params[:user] && params[:user][:password].blank?
          params[:user].delete(:password)
          params[:user].delete(:password_confirmation)
        end
      end

    end
  end
end
