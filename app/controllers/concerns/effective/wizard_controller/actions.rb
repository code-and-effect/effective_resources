module Effective
  module WizardController
    module Actions

      def new
        Rails.logger.info 'Processed by Effective::WizardController#new'

        self.resource ||= (find_wizard_resource || resource_scope.new)
        EffectiveResources.authorize!(self, :new, resource)

        redirect_to resource_wizard_path(
          (resource.to_param || :new),
          (resource.first_uncompleted_step || resource_wizard_steps.first)
        )
      end

      def show
        Rails.logger.info 'Processed by Effective::WizardController#show'

        run_callbacks(:resource_render)
        render_wizard
      end

      def update
        Rails.logger.info 'Processed by Effective::WizardController#update'

        action = (commit_action[:action] == :save ? :update : commit_action[:action])
        EffectiveResources.authorize!(self, action, resource)

        resource.assign_attributes(send(resource_params_method_name))
        assign_current_step

        save_wizard_resource(resource, action)
      end

    end
  end
end
