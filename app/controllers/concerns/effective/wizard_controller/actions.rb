module Effective
  module WizardController
    module Actions

      def new
        Rails.logger.info 'Processed by Effective::WizardController#new'

        self.resource ||= resource_scope.new
        EffectiveResources.authorize!(self, :new, resource)

        redirect_to resource_wizard_path(:new, resource_wizard_steps.first)
      end

      def show
        Rails.logger.info 'Processed by Effective::WizardController#show'

        render_wizard
      end

      def update
        Rails.logger.info 'Processed by Effective::WizardController#update'

        resource.assign_attributes(send(resource_params_method_name))
        render_next_step_if(:save, resource)
      end

    end
  end
end
