module Effective
  module WizardController
    extend ActiveSupport::Concern

    include Wicked::Wizard if defined?(Wicked)
    include Effective::CrudController

    include Effective::WizardController::Actions
    include Effective::WizardController::BeforeActions
    include Effective::WizardController::PermittedParams
    include Effective::WizardController::Save
    include Effective::WizardController::WickedOverrides

    module ClassMethods
      def effective_wizard_controller?; true; end
    end

    included do
      raise("please install gem 'wicked' to use Effective::WizardController") unless defined?(Wicked)

      with_options(only: [:show, :update]) do
        before_action :redirect_if_blank_step

        before_action :assign_resource
        before_action :assign_resource_current_user

        before_action :authorize_resource
        before_action :assign_required_steps

        before_action :setup_wizard # Wicked

        before_action :enforce_can_visit_step

        before_action :redirect_if_existing, only: [:show, :new]
        before_action :clear_flash_success, only: [:update]

        before_action :assign_current_step
        before_action :assign_page_title

        before_action :ready_checkout
      end

      helper_method :resource
      helper_method :resource_wizard_step_title

      helper EffectiveResourcesWizardHelper

      rescue_from Wicked::Wizard::InvalidStepError do |exception|
        step = resource.required_steps.first || resource_wizard_steps.first

        flash[:danger] = "Unknown step. You have been moved to the #{step} step."
        redirect_to wizard_path(step)
      end

      # effective_resources on save callback
      after_action do
        flash.clear if @_delete_flash_success
      end

    end

    def find_wizard_resource
      if params[resource_name_id] && params[resource_name_id] != 'new'
        resource_scope.find(params[resource_name_id])
      else
        build_wizard_resource
      end
    end

    def build_wizard_resource
      resource_scope.new
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
