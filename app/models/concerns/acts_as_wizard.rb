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

  module ClassMethods
    def acts_as_wizard?; true; end

    def wizard_steps_hash
      const_get(:WIZARD_STEPS)
    end

    def all_wizard_steps
      const_get(:WIZARD_STEPS).keys
    end
  end

  included do
    acts_as_wizard_options = @acts_as_wizard_options

    attr_accessor :current_step
    attr_accessor :skip_to_step

    attr_accessor :current_user

    # Used by the view when rendering each partial. Not the current step.
    attr_accessor :render_step
    attr_accessor :render_path

    if Rails.env.test? # So our tests can override the required_steps method
      cattr_accessor :test_required_steps
    end

    const_set(:WIZARD_STEPS, acts_as_wizard_options[:steps])

    effective_resource do
      wizard_steps           :text, permitted: false
    end

    if EffectiveResources.serialize_with_coder?
      serialize :wizard_steps, type: Hash, coder: YAML
    else
      serialize :wizard_steps, Hash
    end

    before_save(if: -> { current_step.present? }) do
      wizard_steps[current_step.to_sym] ||= Time.zone.now
    end

    # Use can_visit_step? required_steps and wizard_step_title(step) to control the wizard behaviour
    def can_visit_step?(step)
      can_revisit_completed_steps(step)
    end

    def wizard_step_keys
      self.class.const_get(:WIZARD_STEPS).keys
    end

    def wizard_steps
      Hash(self[:wizard_steps])
    end

    def all_steps
      wizard_step_keys
    end

    # :submitted
    def last_wizard_step
      all_steps.last
    end

    def completed_steps
      wizard_steps.keys
    end

    def required_steps
      return self.class.test_required_steps if Rails.env.test? && self.class.test_required_steps.present?

      steps = wizard_step_keys()

      # Give the caller class a mechanism to change these.
      # Used more in effective memberships
      steps = change_wizard_steps(steps)

      unless steps.kind_of?(Array) && steps.all? { |step| step.kind_of?(Symbol) }
        raise('expected change_wizard_steps to return an Array of steps with no nils')
      end

      steps
    end

    # Intended for use by calling class
    def change_wizard_steps(steps)
      steps
    end

    def sidebar_steps
      required_steps
    end

    # For use in the summary partials. Does not include summary.
    def render_steps
      blacklist = [:start, :billing, :checkout, :submit, :submitted, :complete, :completed, :summary]
      ((required_steps | completed_steps) - blacklist).select { |step| has_completed_step?(step) }
    end

    def wizard_step_title(step)
      default_wizard_step_title(step)
    end

    def default_wizard_step_title(step)
      self.class.const_get(:WIZARD_STEPS)[step] || step.to_s.titleize
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
      (errors.present? ? wizard_steps_was : wizard_steps)[step].present?
    end

    def next_step
      first_uncompleted_step ||
      last_completed_step ||
      required_steps.reverse.find { |step| can_visit_step?(step) } ||
      required_steps.first ||
      :start
    end

    def all_steps_before(step)
      index = all_steps.index(step)
      raise("unexpected step #{step}") unless index.present?

      all_steps.first(index)
    end

    def all_steps_after(step)
      index = all_steps.index(step)
      raise("unexpected step #{step}") unless index.present?

      all_steps[(index + 1)..-1]
    end

    def reset_all_wizard_steps_after(step)
      all_steps_after(step).each { |step| wizard_steps.delete(step) }
      wizard_steps
    end

    def previous_step(step)
      index = required_steps.index(step)
      required_steps[index-1] unless index == 0 || index.nil?
    end

    def has_completed_previous_step?(step)
      previous = previous_step(step)
      previous.blank? || has_completed_step?(previous)
    end

    def has_completed_all_previous_steps?(step)
      index = required_steps.index(step).to_i
      previous = required_steps[0...index]

      previous.blank? || previous.all? { |step| has_completed_step?(step) }
    end

    def has_completed_last_step?
      has_completed_step?(required_steps.last)
    end

    def start_step_requires_authenticated_user?
      true
    end

    def reset_all_wizard_steps!
      update!(wizard_steps: {})
    end

    def complete_all_wizard_steps!
      now = Time.zone.now
      required_steps.each { |step| wizard_steps[step] ||= now }
      save!
    end

    def without_current_step(&block)
      existing = current_step

      begin
        self.current_step = nil
        yield
      ensure
        self.current_step = existing
      end
    end

    private

    def can_revisit_completed_steps(step)
      return (step == required_steps.last) if has_completed_last_step?
      has_completed_all_previous_steps?(step)
    end

    def cannot_revisit_completed_steps(step)
      return (step == required_steps.last) if has_completed_last_step?
      has_completed_all_previous_steps?(step) && !has_completed_step?(step)
    end

  end
end
