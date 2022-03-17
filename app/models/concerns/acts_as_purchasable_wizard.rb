# ActsAsPurchasableWizard
#

module ActsAsPurchasableWizard
  extend ActiveSupport::Concern

  module Base
    def acts_as_purchasable_wizard
      raise('please declare acts_as_wizard first') unless respond_to?(:acts_as_wizard?)
      raise('please declare acts_as_purchasable_parent first') unless respond_to?(:acts_as_purchasable_parent?)

      unless (const_get(:WIZARD_STEPS).keys & [:billing, :checkout, :submitted]).length == 3
        raise('please include a :billing, :checkout and :submitted step')
      end

      include ::ActsAsPurchasableWizard
    end
  end

  included do
    validates :owner, presence: true

    # Billing Step
    validate(if: -> { current_step == :billing && owner.present? }) do
      self.errors.add(:base, "must have a billing address") unless owner.billing_address.present?
      self.errors.add(:base, "must have an email") unless owner.email.present?
    end

    after_purchase do |_|
      raise('expected submit_order to be purchased') unless submit_order&.purchased?
      before_submit_purchased!
      submit_purchased!
      after_submit_purchased!
    end
  end

  # All Fees and Orders
  def submit_fees
    raise('to be implemented by caller')
  end

  def submit_order
    orders.first
  end

  def find_or_build_submit_fees
    submit_fees
  end

  def find_or_build_submit_order
    order = submit_order || orders.build(user: owner) # This is polymorphic user, might be an organization
    fees = submit_fees().reject { |fee| fee.marked_for_destruction? }

    # A membership could go from individual to organization
    order.user = owner

    # Adds fees, but does not overwrite any existing price.
    fees.each do |fee|
      order.add(fee) unless order.purchasables.include?(fee)
    end

    order.order_items.each do |order_item|
      fee = fees.find { |fee| fee == order_item.purchasable }
      order.remove(order_item) unless fee.present?
    end

    # From Billing Step
    order.billing_address = owner.billing_address if owner.try(:billing_address).present?

    # Important to add/remove anything
    order.save!

    order
  end

  # Should be indempotent.
  def build_submit_fees_and_order
    return false if was_submitted?

    fees = find_or_build_submit_fees()
    raise('already has purchased submit fees') if fees.any?(&:purchased?)

    order = find_or_build_submit_order()
    raise('already has purchased submit order') if order.purchased?

    true
  end

  # Owner clicks on the Billing step. Next step is Checkout
  def billing!
    ready! && save!
  end

  # Ready to check out
  # This is called by the "ready_checkout" before_action in wizard_controller/before_actions.rb
  def ready!
    without_current_step do
      build_submit_fees_and_order
      save!
    end
  end

  # Called automatically via after_purchase hook above
  def submit_purchased!
    return false if was_submitted?

    wizard_steps[:checkout] = Time.zone.now
    submit!
  end

  # A hook to extend
  def before_submit_purchased!
  end

  def after_submit_purchased!
  end

  # Draft -> Submitted requirements
  def submit!
    raise('already submitted') if was_submitted?
    raise('expected a purchased order') unless submit_order&.purchased?

    wizard_steps[:checkout] ||= Time.zone.now
    wizard_steps[:submitted] = Time.zone.now
    submitted!
  end

  module ClassMethods
    def acts_as_purchasable_wizard?; true; end
  end

end
