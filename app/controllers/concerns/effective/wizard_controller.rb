module Effective
  module WizardController
    extend ActiveSupport::Concern

    include Wicked::Wizard if defined?(Wicked)
    include Effective::CrudController

    include Effective::WizardController::Actions
    include Effective::WizardController::BeforeActions
    include Effective::WizardController::Save
    include Effective::WizardController::WickedOverrides

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

    def resource_wizard_step_title(resource, step)
      return if step == 'wicked_finish'
      resource.wizard_step_title(step)
    end

    def resource_wizard_steps
      effective_resource.klass.const_get(:WIZARD_STEPS).keys
    end

    # It could be :new, :start
    # Or resource, step
    def resource_wizard_path(resource, step)
      param = (resource.respond_to?(:to_param) ? resource.to_param : resource)
      wizard_path(step, resource_name_id => param)
    end

    private

    def current_step_before?(nav_step)
      index = wizard_steps.index(nav_step) || raise("step #{nav_step} not found in wizard_steps")
      current = wizard_steps.index(step) || raise("current step not found in wizard_steps")
      current < index
    end

    def current_step_after?(nav_step)
      index = wizard_steps.index(nav_step) || raise("step #{nav_step} not found in wizard_steps")
      current = wizard_steps.index(step) || raise("current step not found in wizard_steps")
      current > index
    end

  end
end
