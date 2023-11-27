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

    serialize :status_steps, type: Hash, coder: YAML

    const_set(:STATUSES, acts_as_statused_options[:statuses])

    before_validation do
      self.status ||= all_statuses.first

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

      # just_approved?
      define_method("just_#{sym}?") { status == sym.to_s && status_was != sym.to_s }

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

          klass.constantize.find_by_id(id) if id.present? && klass.present?
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
      define_method("un#{sym}!") do |atts = {}|
        raise 'expected a Hash of passed attributes' unless atts.kind_of?(Hash)

        self.try("#{sym}_at=", nil)
        self.try("#{sym}_by=", nil)
        self.try("#{sym}_by_id=", nil)
        self.try("#{sym}_by_type=", nil)

        status_steps.delete(sym_at)
        status_steps.delete(sym_by_id)
        status_steps.delete(sym_by_type)

        if status == sym.to_s # I was just this status
          assign_attributes(status: last_completed_status || all_statuses.first)
        end

        # Assign atts if present
        assign_attributes(atts) if atts.present?

        save!
      end
    end

    # Regular instance methods
    # Sort of matches acts_as_wizard
    def status_keys
      self.class.const_get(:STATUSES)
    end

    def all_statuses
      status_keys
    end

    def completed_statuses
      all_statuses.select { |status| has_completed_status?(status) }
    end

    def last_completed_status
      all_statuses.reverse.find { |status| has_completed_status?(status) }
    end

    def has_completed_status?(status)
      (errors.present? ? status_steps_was : status_steps)["#{status}_at".to_sym].present?
    end

  end

  module ClassMethods
    def acts_as_statused?; true; end
  end

end
