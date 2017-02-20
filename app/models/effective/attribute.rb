module Effective
  class Attribute
    attr_accessor :name, :type, :klass

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
    def initialize(obj, type = nil, klass: nil)
      @klass = klass

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
        when :price     ; :price
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
        date = Time.zone.local(*value.to_s.scan(/(\d+)/).flatten)
        name.to_s.start_with?('end_') ? date.end_of_day : date
      when :decimal
        (value.kind_of?(String) ? value.gsub(/[^0-9|\.]/, '') : value).to_f
      when :effective_obfuscation
        klass.respond_to?(:deobfuscate) ? klass.deobfuscate(value) : value.to_s
      when :effective_roles
        EffectiveRoles.roles_for(value)
      when :integer
        (value.kind_of?(String) ? value.gsub(/\D/, '') : value).to_i
      when :nil
        value.presence
      when :price
        (value.kind_of?(Integer) ? value : (value.to_s.gsub(/[^0-9|\.]/, '').to_f * 100.0)).to_i
      when :string
        value.to_s
      when :belongs_to, :has_many, :has_and_belongs_to_many, :has_one  # Returns an Array of ints, an Int or String
        if value.kind_of?(Integer) || value.kind_of?(Array)
          value
        else
          digits = value.to_s.gsub(/[^0-9|,]/, '') # 87 or 87,254,300 or Skills

          if digits == value && digits.index(',').present?
            if klass.respond_to?(:deobfuscate)
              digits.split(',').map { |str| klass.deobfuscate(str).to_i }
            else
              digits.split(',').map { |str| str.to_i }
            end
          elsif digits == value
            klass.respond_to?(:deobfuscate) ? klass.deobfuscate(digits).to_i : digits.to_i
          else
            value.to_s
          end
        end
      else
        raise 'unsupported type'
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
