module Effective
  class Attribute
    attr_accessor :name, :type

    # This parses the written attributes
    def self.parse_written(input)
      input = input.to_s

      if (scanned = input.scan(/^\W*(\w+)\W*:(\w+)/).first).present?
        new(*scanned)
      elsif input.start_with?('#')
        new(nil)
      else
        new(input)
      end
    end

    # This kind of follows the rails GeneratedAttribute method.
    # In that case it will be initialized with a name and a type.

    # We also use this class to do value parsing in Datatables.
    # In that case it will be initialized with just a 'name'
    def initialize(obj, type = nil, options = {})
      @options = options

      if obj.present? && type.present?
        @name = obj.to_s
        @type = type.to_sym
      end

      @type = (
        case obj
        when :boolean   ; :boolean
        when :date      ; :date
        when :datetime  ; :datetime
        when :decimal   ; :decimal
        when :integer   ; :integer
        when :nil       ; :nil
        when :string    ; :string
        when FalseClass ; :boolean
        when Fixnum     ; :integer
        when Float      ; :decimal
        when NilClass   ; :nil
        when String     ; :string
        when TrueClass  ; :boolean
        when ActiveSupport::TimeWithZone  ; :datetime
        when :belongs_to                  ; :belongs_to
        when :belongs_to_polymorphic      ; :belongs_to_polymorphic
        when :has_many                    ; :has_many
        when :has_and_belongs_to_many     ; :has_and_belongs_to_many
        when :has_one                     ; :has_one
        when :effective_address           ; :effective_address
        when :effective_obfuscation       ; :effective_obfuscation
        when :effective_roles             ; :effective_roles
        else
          raise 'unsupported type'
        end
      )
    end

    def parse(value, name: nil)
      case type
      when :boolean
        [true, 'true', 't', '1'].include?(value)
      when :date, :datetime
        if name.to_s.start_with?('end_')
          Time.zone.parse(value).end_of_day
        else
          Time.zone.parse(value)
        end
      when :decimal
        value.to_f
      when :integer
        value.to_i
      when :nil
        value.presence
      when :string
        value.to_s
      end
    end

    def to_s
      name
    end

    def present?
      name.present? || type.present?
    end

    def human_name
      name.humanize
    end

    def <=>(other)
      name <=> other.name
    end

    def ==(other)
      name == other.name && type == other.type
    end

  end
end
