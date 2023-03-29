# ActsAsStatused
# This is kind of like a state machine, but the statuses only go forward.
#
# Initialize with a set of statuses like [:submitted, :approved, :declined]. Creates the following:
# scope :approved
# approved?, was_approved?, approved_at, approved_by, approved!, unapproved!

module ActsAsStatused
  extend ActiveSupport::Concern

  module Base
    # acts_as_statused :pending, :approved, :declined, option_key: :option_value
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
      if respond_to?("#{status}_by") && send("#{status}_by").blank?
        self.send("#{status}_by=", current_user)
      end

      # Set an existing timestamp automatically
      if respond_to?("#{status}_at") && send("#{status}_at").blank?
        self.send("#{status}_at=", Time.zone.now)
      end

      if current_user.present?
        self.status_steps["#{status}_by_id".to_sym] ||= current_user.id
        self.status_steps["#{status}_by_type".to_sym] ||= current_user.class.name
      end

      self.status_steps["#{status}_at".to_sym] ||= Time.zone.now
    end

    validates :status, presence: true, inclusion: { in: const_get(:STATUSES).map(&:to_s) }

    # Create an received scope and approved? method for each status
    acts_as_statused_options[:statuses].each do |sym|
      sym_at = "#{sym}_at".to_sym
      sym_by = "#{sym}_by".to_sym
      sym_by_id = "#{sym}_by_id".to_sym
      sym_by_type = "#{sym}_by_type".to_sym

      scope(sym, -> { where(status: sym.to_s) })

      # approved?
      define_method("#{sym}?") { status == sym.to_s }

      # was_approved?
      define_method("was_#{sym}?") { send(sym_at).present? }

      # approved_at
      define_method(sym_at) { self[sym_at.to_s] || status_steps[sym_at] }

      # approved_by_id
      define_method(sym_by_id) { self[sym_by_id.to_s] || status_steps[sym_by_id] }

      # approved_by_type
      define_method(sym_by_type) { self[sym_by_type.to_s] || status_steps[sym_by_type] }

      # approved_by
      define_method(sym_by) do
        user = (super() if attributes.key?(sym_by_id.to_s))

        user ||= begin
          id = status_steps[sym_by_id]
          klass = status_steps[sym_by_type]

          klass.constantize.find(id) if id.present? && klass.present?
        end
      end

      # approved_at=
      define_method("#{sym_at}=") do |value|
        super(value) if attributes.key?(sym_at.to_s)
        status_steps[sym_at] = value
      end

      # approved_by_id=
      define_method("#{sym_by_id}=") do |value|
        super(value) if attributes.key?(sym_by_id.to_s)
        status_steps[sym_by_id] = value
      end

      # approved_by_type=
      define_method("#{sym_by_type}=") do |value|
        super(value) if attributes.key?(sym_by_type.to_s)
        status_steps[sym_by_type] = value
      end

      # approved_by=
      define_method("#{sym_by}=") do |value|
        super(value) if attributes.key?(sym_by_id.to_s)
        status_steps[sym_by_id] = value&.id
        status_steps[sym_by_type] = value&.class&.name
      end

      # approved!
      define_method("#{sym}!") do |atts = {}|
        raise 'expected a Hash of passed attributes' unless atts.kind_of?(Hash)
        update!(atts.merge(status: sym))
      end

      # unapproved!
      define_method("un#{sym}!") do
        self.status = nil if (status == sym.to_s)

        if respond_to?("#{sym}_at") && send("#{sym}_at").present?
          self.send("#{sym}_at=", nil)
        end

        if respond_to?("#{sym}_by") && send("#{sym}_by").present?
          self.send("#{sym}_by=", nil)
        end

        status_steps.delete(sym_at)
        status_steps.delete(sym_by_id)
        status_steps.delete(sym_by_type)

        true
      end

    end
  end

  module ClassMethods
    def acts_as_statused?; true; end
  end

end
