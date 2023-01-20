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

      def assign_resource_current_user
        return unless respond_to?(:current_user)
        resource.current_user ||= current_user
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

      # Allow only 1 in-progress wizard at a time
      def redirect_if_existing
        return if step == 'wicked_finish'
        return if resource.blank?
        return if resource.try(:done?)
        return unless resource_scope.respond_to?(:in_progress)

        existing = resource_scope.in_progress.order(:id).where.not(id: resource).first
        return unless existing.present?
        return if (existing.id > resource.id) # Otherwise we get an infinite loop

        flash[:success] = "You have been redirected to your in-progress wizard"
        redirect_to resource_wizard_path(existing, existing.next_step)
      end

      # before_action :enforce_can_visit_step, only: [:show, :update]
      # Make sure I have permission for this step
      def enforce_can_visit_step
        return if step == 'wicked_finish'
        return if resource.can_visit_step?(step)

        next_step = wizard_steps.reverse.find { |step| resource.can_visit_step?(step) }
        raise('There is no wizard step to visit. Make sure can_visit_step?(step) returns true for at least one step') unless next_step

        if Rails.env.development?
          Rails.logger.info "  \e[31m\e[1mFAILED\e[0m\e[22m" # bold red
          Rails.logger.info "  Unable to visit step :#{step}. Last can_visit_step? is :#{next_step}. Change the acts_as_wizard model's can_visit_step?(step) function to change this."
        end

        flash[:success] = "You have been redirected to the #{resource_wizard_step_title(resource, next_step)} step."
        redirect_to wizard_path(next_step)
      end

      # before_action :assign_current_step, only: [:show, :update]
      # Assign the current step to resource
      def assign_current_step
        resource.current_step = step.to_sym
      end

      # before_action :assign_page_title, only: [:show, :update]
      # Assign page title
      def assign_page_title
        @page_title ||= resource_wizard_step_title(resource, step)
      end

      def ready_checkout
        return unless step == :checkout
        return unless resource.class.try(:acts_as_purchasable_wizard?)

        resource.ready!
      end

      def clear_flash_success
        @_delete_flash_success = true
      end

    end
  end
end
