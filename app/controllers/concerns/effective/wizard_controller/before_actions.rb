module Effective
  module WizardController
    module BeforeActions

      # before_action :redirect_if_blank_step, only: [:show]
      # When I visit /resources/1, redirect to /resources/1/build/step
      def redirect_if_blank_step
        if params[:id].present? && params[resource_name_id].blank?
          params[resource_name_id] = params[:id]

          assign_resource()

          step = (resource.first_uncompleted_step || resource_wizard_steps.last)
          redirect_to resource_wizard_path(resource, step)
        end
      end

      # before_action :assign_resource, only: [:show, :update]
      # Assigns the resource
      def assign_resource
        self.resource ||= find_wizard_resource
      end

      # before_action :authorize_resource, only: [:show, :update]
      # Authorize the resource
      def authorize_resource
        EffectiveResources.authorize!(self, action_name.to_sym, resource)
      end

      # before_action :assign_required_steps, only: [:show, :update]
      # Assign the required steps to Wickeds (dynamic steps)
      def assign_required_steps
        self.steps = resource.required_steps
      end

      # setup_wizard from Wicked called now

      # before_action :enforce_can_visit_step, only: [:show, :update]
      # Make sure I have permission for this step
      def enforce_can_visit_step
        nav_step = step

        return if resource.can_visit_step?(step)

        permitted_step = resource.first_uncompleted_step || resource_wizard_steps.first

        flash[:danger] = "Please complete the #{permitted_step} step before continuing."
        redirect_to wizard_path(permitted_step)
      end

      # before_action :assign_current_step, only: [:show, :update]
      # Assign the urrent step to resource
      def assign_current_step
        if respond_to?(:current_user) && resource.respond_to?('current_user=')
          resource.current_user = current_user
        end

        resource.current_step = step.to_sym
      end

      # before_action :assign_page_title, only: [:show, :update]
      # Assign page title
      def assign_page_title
        @page_title ||= resource_wizard_step(step)
      end

    end
  end
end
