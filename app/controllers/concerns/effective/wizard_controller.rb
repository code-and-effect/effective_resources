module Effective
  module WizardController
    extend ActiveSupport::Concern

    include Wicked::Wizard if defined?(Wicked)
    include Effective::CrudController

    include Effective::WizardController::Actions
    include Effective::WizardController::BeforeActions
    include Effective::WizardController::Save

    included do
      raise("please install gem 'wicked' to use Effective::WizardController") unless defined?(Wicked)

      with_options(only: [:show, :update]) do
        before_action :redirect_if_blank_step

        before_action :assign_resource
        before_action :authorize_resource
        before_action :assign_required_steps
        before_action :setup_wizard # Wicked

        before_action :enforce_can_visit_step

        before_action :assign_current_step
        before_action :assign_page_title
      end

      helper_method :resource
      helper_method :resource_wizard_step_title

      helper EffectiveResourcesWizardHelper

      rescue_from Wicked::Wizard::InvalidStepError do |exception|
        flash[:danger] = "Unknown step. You have been moved to the #{resource_wizard_steps.first} step."
        redirect_to wizard_path(resource_wizard_steps.first)
      end
    end

    def find_wizard_resource
      if params[resource_name_id] && params[resource_name_id] != 'new'
        resource_scope.find(params[resource_name_id])
      else
        resource_scope.new
      end
    end

    def resource_wizard_step_title(step)
      return if step == 'wicked_finish'
      effective_resource.klass.const_get(:WIZARD_STEPS).fetch(step)
    end

    def resource_wizard_steps
      effective_resource.klass.const_get(:WIZARD_STEPS).keys
    end

    def resource_wizard_path(resource, step)
      path_helper = effective_resource.action_path_helper(:show).to_s.sub('_path', '_build_path')

      effective_resource.url_helpers.public_send(path_helper, resource, step)
    end

  end
end
