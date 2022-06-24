module Admin
  class Select2AjaxController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_resources) }

    include Effective::Select2AjaxController

    def users
      collection = current_user.class.all

      # Search
      if (term = params[:term]).present?
        collection = collection
          .where('first_name ILIKE ?', "%#{term}%")
          .or(collection.where('last_name ILIKE ?', "%#{term}%"))
          .or(collection.where('email ILIKE ?', "%#{term}%"))
      end

      respond_with_select2_ajax(collection) do |user|
        { id: user.to_param, text: "#{user.first_name} #{user.last_name} <#{user.email}>" }
      end

    end

  end

end
