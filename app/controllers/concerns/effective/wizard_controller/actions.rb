module Effective
  module WizardController
    module Actions

      def new
        Rails.logger.info 'Processed by Effective::WizardController#new'

        self.resource ||= resource_scope.new
        EffectiveResources.authorize!(self, :new, resource)

        redirect_to resource_wizard_path(:new, resource_wizard_steps.first)
      end

    end
  end
end
