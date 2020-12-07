# ActsAsWizard
# Works alongside wicked gem to build a wizard
# https://github.com/zombocom/wicked

# acts_as_wizard(start: 'Start Step', select: 'Select Step', finish: 'Finished')

module ActsAsWizard
  extend ActiveSupport::Concern

  module Base
    def acts_as_wizard(steps)
      raise 'acts_as_wizard expected a Hash of steps' unless steps.kind_of?(Hash)

      unless steps.all? { |k, v| k.kind_of?(Symbol) && v.kind_of?(String) }
        raise 'acts_as_wizard expected a Hash of symbol => String steps'
      end

      @acts_as_wizard_options = {steps: steps}

      include ::ActsAsWizard
    end
  end

  included do
    acts_as_wizard_options = @acts_as_wizard_options

    attr_accessor :current_step
    attr_accessor :current_user

    if Rails.env.test? # So our tests can override the required_steps method
      cattr_accessor :test_required_steps
    end

    const_set(:WIZARD_STEPS, acts_as_wizard_options[:steps])

    effective_resource do
      wizard_steps           :text, permitted: false
    end

    serialize :wizard_steps, Hash

    before_save(if: -> { current_step.present? }) do
      wizard_steps[current_step.to_sym] ||= Time.zone.now
    end

    def can_visit_step?(step)
      can_revisit_completed_steps(step)
    end

    def required_steps
      return self.class.test_required_steps if Rails.env.test? && self.class.test_required_steps.present?
      self.class.const_get(:WIZARD_STEPS).keys
    end

    def first_completed_step
      required_steps.find { |step| has_completed_step?(step) }
    end

    def last_completed_step
      required_steps.reverse.find { |step| has_completed_step?(step) }
    end

    def first_uncompleted_step
      required_steps.find { |step| has_completed_step?(step) == false }
    end

    def has_completed_step?(step)
      wizard_steps[step].present?
    end

    def previous_step(step)
      index = required_steps.index(step)
      required_steps[index-1] unless index == 0 || index.nil?
    end

    def has_completed_previous_step?(step)
      previous = previous_step(step)
      previous.blank? || has_completed_step?(previous)
    end

    def has_completed_last_step?
      has_completed_step?(required_steps.last)
    end

    private

    def can_revisit_completed_steps(step)
      return (step == required_steps.last) if has_completed_last_step?
      has_completed_previous_step?(step)
    end

    def cannot_revisit_completed_steps(step)
      return (step == required_steps.last) if has_completed_last_step?
      has_completed_previous_step?(step) && !has_completed_step?(step)
    end

  end

  module ClassMethods
    def acts_as_wizard?; true; end
  end

end
