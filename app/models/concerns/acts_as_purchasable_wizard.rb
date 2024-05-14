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

    after_defer do |_|
      raise('expected submit_order to be deferred') unless submit_order&.deferred?
      before_submit_deferred!
      submit_deferred!
      after_submit_deferred!
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
    orders.last
  end

  def find_or_build_submit_fees
    submit_fees
  end

  def build_effective_order
    if EffectiveOrders.organization_enabled? && respond_to?(:organization) # New style
      orders.build(organization: organization)
    else
      orders.build(user: owner) # This is polymorphic user, might be an organization. Old style.
    end
  end

  def find_or_build_submit_order
    order = submit_order || build_effective_order()
    order = build_effective_order() if order.declined? # Make a new order, if the previous one was declined

    # Update the order with the current owner
    if EffectiveOrders.organization_enabled? && respond_to?(:organization)
      order.organization = organization
    else
      # A membership could go from individual to organization
      order.user = owner 
    end

    # Consider fees
    fees = submit_fees().reject { |fee| fee.marked_for_destruction? }

    # Make sure all Fees are valid
    fees.each do |fee|
      raise("expected a valid fee but #{fee.id} had errors #{fee.errors.inspect}") unless fee.valid?
    end

    # Adds fees, but does not overwrite any existing price.
    fees.each do |fee|
      order.add(fee) unless order.purchasables.include?(fee)
    end

    # Remove any order items that no longer have fees for them
    order.order_items.each do |order_item|
      fee = fees.find { |fee| fee == order_item.purchasable }
      order.remove(order_item) unless fee.present?
    end

    # From Billing Step
    order.billing_address = owner.billing_address if owner.try(:billing_address).present?

    # This will update all order items to match the prices from their purchasable
    order.try(:update_purchasable_attributes)

    # Handle effective_memberships coupon fees price reduction
    reduce_order_item_coupon_fee_price(order)

    # Hook to extend for coupon fees
    order = before_submit_order_save(order)
    raise('before_submit_order_save must return an Effective::Order') unless order.kind_of?(Effective::Order)

    # Important to add/remove anything
    order.save!

    order
  end

  def before_submit_order_save(order)
    order
  end

  # This is used by effective_memberships and effective_events
  # Which both add coupon_fees to their submit_fees
  def reduce_order_item_coupon_fee_price(order)
    # This only applies to orders with coupon fees
    order_items = order.order_items.select { |oi| oi.purchasable.try(:coupon_fee?) }
    return order unless order_items.present?
    raise('multiple coupon fees not supported') if order_items.length > 1

    # Get the coupon fee
    order_item = order_items.first
    coupon_fee = order_item.purchasable
    raise('expected order item for coupon fee to be a negative price') unless coupon_fee.price.to_i < 0

    # Calculate price
    subtotal = order.order_items.reject { |oi| oi.purchasable.try(:coupon_fee?) }.sum(&:subtotal)

    price = 0 if subtotal <= 0
    price ||= [coupon_fee.price, (0 - subtotal)].max

    # Assign the price to this order item. Underlying fee price stays the same.
    order_item.assign_attributes(price: price)

    # Return the order
    order
  end

  # Should be indempotent.
  def build_submit_fees_and_order
    return false if was_submitted?

    fees = find_or_build_submit_fees()
    raise('already has purchased submit fees') if Array(fees).any?(&:purchased?)

    order = find_or_build_submit_order()
    raise('expected an Effective::Order') unless order.kind_of?(Effective::Order)
    raise('already has purchased submit order') if order.purchased?
    raise('unable to proceed with a voided submit order') if order.try(:voided?)

    true
  end

  # Called by effective_memberships and effective_events
  def with_outstanding_coupon_fees(purchasables)
    return purchasables unless owner.respond_to?(:outstanding_coupon_fees) # effective_memberships_owner
    raise('expected has_many fees') unless respond_to?(:fees)

    price = purchasables.reject { |p| p.try(:coupon_fee?) }.map { |p| p.price || 0 }.sum

    if price > 0
      Array(owner.outstanding_coupon_fees).each { |fee| fees << fee unless fees.include?(fee) }
    else
      Array(owner.outstanding_coupon_fees).each { |fee| fees.delete(fee) if fees.include?(fee) }
    end

    (purchasables + fees).uniq
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

  # The historic way of handling a deferred order checkout is to return to the :checkout step and not call wizard submit!
  # With effective_events date delayed payments, we do call wizard submit! and proceed to the :submitted step.

  # False by default - do not call submit
  def submit_wizard_on_deferred_order?
    false
  end

  # Called automatically via after_defer hook above
  def submit_deferred!
    return unless submit_wizard_on_deferred_order?
    return false if was_submitted?

    wizard_steps[:checkout] = Time.zone.now
    submit!
  end

  # A hook to extend
  def before_submit_deferred!
  end

  def after_submit_deferred!
  end

  # Called automatically via after_purchase hook above
  # If previously submitted, possibly with deferred order, just save so any before_save or validate can run.
  def submit_purchased!
    return save! if was_submitted?

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

    if submit_wizard_on_deferred_order?
      raise('expected a purchased or deferred order') unless (submit_order&.purchased? || submit_order&.deferred?)
    else
      raise('expected a purchased order') unless submit_order&.purchased?
    end

    wizard_steps[:checkout] ||= Time.zone.now
    wizard_steps[:submitted] = Time.zone.now
    submitted!
  end

  module ClassMethods
    def acts_as_purchasable_wizard?; true; end
  end

end
