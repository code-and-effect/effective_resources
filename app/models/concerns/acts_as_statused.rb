# ActsAsStatused
# This is kind of like a state machine, but the statuses only go forward.
#
# Initialize with a set of statuses like [:submitted, :approved, :declined]. Creates the following:
# scope :approved
# approved?, was_approved?, approved_at, approved_by, approved!, unapproved!

module ActsAsStatused
  extend ActiveSupport::Concern

  module ActiveRecord
    # acts_as_statuses :pending, :approved, :declined, option_key: :option_value
    def acts_as_statused(*args)
      options = args.extract_options!
      statuses = Array(args).compact

      if statuses.blank? || statuses.any? { |status| !status.kind_of?(Symbol) }
        raise 'acts_as_statused expected one or more statuses'
      end

      @acts_as_statused_options = options.merge(statuses: statuses)

      include ::ActsAsStatused
    end
  end

  module CanCan
    # The idea here is you can go forward but you can't go back.
    def acts_as_statused(klass, only: nil, except: nil)
      raise "klass does not implement acts_as_statused" unless klass.acts_as_statused?

      statuses = klass.const_get(:STATUSES)
      instance = klass.new

      only = Array(only).compact
      except = Array(except).compact

      statuses.each_with_index do |status, index|
        action = status_active_verb(status, instance)

        next if action.blank?
        next if only.present? && !only.include?(action)
        next if except.present? && except.include?(action)

        if index == 0
          can(action, klass) and next
        end

        if status == :approved && statuses.include?(:declined)
          if (position = statuses.index { |status| (status == :approved || status == :declined) }) > 0
            can(action, klass) { |obj| obj.public_send("#{statuses[position-1]}?") || obj.declined? }
            next
          end
        end

        if status == :declined && statuses.include?(:approved)
          if (position = statuses.index { |status| (status == :approved || status == :declined) }) > 0
            can(action, klass) { |obj| obj.public_send("#{statuses[position-1]}?") }
            next
          end
        end

        can(action, klass) { |obj| obj.public_send("#{statuses[index-1]}?") }
      end
    end

    private

    # requested -> request, approved -> approve, declined -> decline, pending -> pending
    def status_active_verb(status, instance)
      status = status.to_s.strip

      if status.end_with?('ied')
        action = status[0...-3] + 'y'
        return action.to_sym if instance.respond_to?(action + '!')
      end

      # ed, e, ing
      [-1, -2, -3].each do |index|
        action = status[0...index]
        return action.to_sym if instance.respond_to?(action + '!')
      end

      nil
    end
  end

  included do
    acts_as_statused_options = @acts_as_statused_options

    attr_accessor :current_user

    effective_resource do
      status                 :string, permitted: false
      status_steps           :text, permitted: false
    end

    serialize :status_steps, Hash

    const_set(:STATUSES, acts_as_statused_options[:statuses])

    before_validation do
      self.status ||= self.class.const_get(:STATUSES).first

      # Set an existing belongs_to automatically
      if respond_to?("#{status}_by=") && respond_to?("#{status}_by") && send("#{status}_by").blank?
        self.send("#{status}_by=", current_user)
      end

      # Set an existing timestamp automatically
      if respond_to?("#{status}_at=") && respond_to?("#{status}_at") && send("#{status}_at").blank?
        self.send("#{status}_at=", Time.zone.now)
      end

      self.status_steps["#{status}_at".to_sym] ||= Time.zone.now
      self.status_steps["#{status}_by".to_sym] ||= current_user.try(:id)
    end

    validates :status, presence: true, inclusion: { in: const_get(:STATUSES).map(&:to_s) }

    # Create an received scope and approved? method for each status
    acts_as_statused_options[:statuses].each do |sym|
      define_method("#{sym}?") { status == sym.to_s }
      define_method("was_#{sym}?") { send("#{sym}_at").present? }

      unless has_attribute?("#{sym}_at")
        define_method("#{sym}_at") { status_steps["#{sym}_at".to_sym] }
        define_method("#{sym}_at=") { |value| status_steps["#{sym}_at".to_sym] = value }
      end

      unless has_attribute?("#{sym}_by_id")
        define_method("#{sym}_by") { acts_as_statused_by_user(sym) }
        define_method("#{sym}_by_id") { status_steps["#{sym}_by".to_sym] }
        define_method("#{sym}_by_id=") { |value| status_steps["#{sym}_by".to_sym] = value }
      end

      # approved!
      define_method("#{sym}!") do |atts = {}|
        raise 'expected a Hash of passed attributes' unless atts.kind_of?(Hash)
        update!(atts.merge(status: sym))
      end

      # unapproved!
      define_method("un#{sym}!") do
        self.status = nil if (status == sym.to_s)

        status_steps.delete("#{sym}_at".to_sym)
        status_steps.delete("#{sym}_by".to_sym)

        if respond_to?("#{sym}_at=") && respond_to?("#{sym}_at") && send("#{sym}_at").present?
          self.send("#{sym}_at=", nil)
        end

        if respond_to?("#{sym}_by=") && respond_to?("#{sym}_by") && send("#{sym}_by").present?
          self.send("#{sym}_by=", nil)
        end

        true
      end

      scope(sym, -> { where(status: sym.to_s) })
    end
  end

  module ClassMethods
    def acts_as_statused?; true; end
  end

  private

  def acts_as_statused_by_user(status)
    return nil if status_steps["#{status}_by".to_sym].blank?

    @acts_as_statused_by_users ||= begin
      User.where(id: status_steps.map { |k, v| v.presence if k.to_s.end_with?('_by') }.compact).all.inject({}) { |h, user| h[user.id] = user; h }
    end

    @acts_as_statused_by_users[status_steps["#{status}_by".to_sym]]
  end

end

