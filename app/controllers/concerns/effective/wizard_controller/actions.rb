module Effective
  module WizardController
    module Actions

      def new
        Rails.logger.info 'Processed by Effective::WizardController#new'

        self.resource ||= resource_scope.new
        EffectiveResources.authorize!(self, :new, resource)

        redirect_to resource_wizard_path(:new, resource_wizard_steps.first)
      end

      # Fixes show urls
      # When I visit /resources/1 go to /resources/1/build/step
      def redirect_if_blank_step
        if params[:id].present? && params[resource_name_id].blank?
          params[resource_name_id] = params[:id]

          assign_wizard_resource()

          current_step = (resource.first_uncompleted_step || Import::WIZARD_STEPS.keys.last)
          redirect_to resource_wizard_path(resource, current_step)
        end
      end


    end
  end
end
