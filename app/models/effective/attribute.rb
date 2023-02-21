module Effective
  class Attribute
    attr_accessor :name, :type, :klass

    # This parses the written attributes
    def self.parse_written(input)
      input = input.to_s

      if (scanned = input.scan(/^\W*(\w+)\W*:(\w+)/).first).present?
        new(*scanned)
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

      @type ||= (
        case obj
        when :boolean     ; :boolean
        when :config      ; :config
        when :currency    ; :currency
        when :date        ; :date
        when :datetime    ; :datetime
        when :decimal     ; :decimal
        when :duration    ; :duration
        when :email       ; :email
        when :integer     ; :integer
        when :percent     ; :percent
        when :percentage  ; :percent
        when :phone       ; :phone
        when :price       ; :price
        when :nil         ; :nil
        when :resource    ; :resource
        when :select      ; :string
        when :radios      ; :string
        when :string      ; :string
        when :text        ; :string
        when :time        ; :time
        when :uuid        ; :uuid
        when FalseClass   ; :boolean
        when (defined?(Integer) ? Integer : Fixnum) ; :integer
        when Float        ; :decimal
        when NilClass     ; :nil
        when String       ; :string
        when TrueClass    ; :boolean
        when ActiveSupport::TimeWithZone  ; :datetime
        when Date                         ; :date
        when ActiveRecord::Base           ; :resource
        when :belongs_to                  ; :belongs_to
        when :belongs_to_polymorphic      ; :belongs_to_polymorphic
        when :has_many                    ; :has_many
        when :has_and_belongs_to_many     ; :has_and_belongs_to_many
        when :has_one                     ; :has_one
        when :effective_addresses         ; :effective_addresses
        when :effective_obfuscation       ; :effective_obfuscation
        when :effective_roles             ; :effective_roles
        when :active_storage              ; :active_storage
        else
          raise "unsupported type for #{obj}"
        end
      )
    end

    def parse(value, name: nil)
      case type
      when :boolean
        [true, 'true', 't', '1'].include?(value)
      when :config
        raise('expected an ActiveSupport::OrderedOptions') unless value.kind_of?(ActiveSupport::OrderedOptions)
        parse_ordered_options(value)
      when :date, :datetime
        if (digits = value.to_s.scan(/(\d+)/).flatten).present?
          date = if digits.first.length == 4  # 2017-01-10
            (Time.zone.local(*digits) rescue nil)
          else # 01/10/2016
            year = digits.find { |d| d.length == 4}
            digits = [year] + (digits - [year])
            (Time.zone.local(*digits) rescue nil)
          end

          name.to_s.start_with?('end_') ? date.end_of_day : date
        end
      when :time
        if (digits = value.to_s.scan(/(\d+)/).flatten).present?
          now = Time.zone.now
          (Time.zone.local(now.year, now.month, now.day, *digits) rescue nil)
        end
      when :decimal, :currency
        (value.kind_of?(String) ? value.gsub(/[^0-9|\-|\.]/, '') : value).to_f
      when :duration
        if value.to_s.include?('h')
          (hours, minutes) = (value.to_s.gsub(/[^0-9|\-|h]/, '').split('h'))
          (hours.to_i * 60) + ((hours.to_i < 0) ? -(minutes.to_i) : minutes.to_i)
        else
          value.to_s.gsub(/[^0-9|\-|h]/, '').to_i
        end
      when :effective_obfuscation
        klass.respond_to?(:deobfuscate) ? klass.deobfuscate(value) : value.to_s
      when :effective_roles
        EffectiveRoles.roles.include?(value.to_sym) ? value : EffectiveRoles.roles_for(value)
      when :integer
        (value.kind_of?(String) ? value.gsub(/\D/, '') : value).to_i
      when :percent # Integer * 1000. Percentage to 3 digits.
        value.kind_of?(Integer) ? value : (value.to_s.gsub(/[^0-9|\-|\.]/, '').to_f * 1000.0).round
      when :phone
        digits = value.to_s.gsub(/\D/, '').chars
        digits = (digits.first == '1' ? digits[1..10] : digits[0..9]) # Throw away a leading 1

        return nil unless digits.length == 10

        "(#{digits[0..2].join}) #{digits[3..5].join}-#{digits[6..10].join}"
      when :integer
        (value.kind_of?(String) ? value.gsub(/\D/, '') : value).to_i
      when :nil
        value.presence
      when :price # Integer * 100. Number of cents.
        value.kind_of?(Integer) ? value : (value.to_s.gsub(/[^0-9|\-|\.]/, '').to_f * 100.0).round
      when :string
        value.to_s
      when :email
        return nil unless value.kind_of?(String)

        if value.include?('<') && value.include?('>')
          value = value.match(/<(.+)>/)[1].to_s  # John Smith <john.smith@hotmail.com>
        end

        if value.include?(',')
          value = value.split(',').find { |str| str.include?('@') }.to_s
        end

        if value.include?(' ')
          value = value.split(' ').find { |str| str.include?('@') }.to_s
        end

        value = value.to_s.downcase.strip

        return nil unless value.include?('@') && value.include?('.')

        if defined?(Devise)
          return nil unless Devise::email_regexp.match?(value)
        end

        value
      when :belongs_to_polymorphic
        value.to_s
      when :belongs_to, :has_many, :has_and_belongs_to_many, :has_one, :resource, :effective_addresses  # Returns an Array of ints, an Int or String
        if value.kind_of?(Integer) || value.kind_of?(Array)
          value
        else
          digits = value.to_s.gsub(/[^0-9|,]/, '') # '87' or '87,254,300' or 'something'

          if digits == value || digits.length == 10
            if klass.respond_to?(:deobfuscate)
              digits.split(',').map { |str| klass.deobfuscate(str).to_i }
            else
              digits.split(',').map { |str| str.to_i }
            end
          else
            value.to_s
          end
        end
      when :uuid
        value.to_s
      when :active_storage
        value.to_s
      else
        raise "unsupported type #{type}"
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

    # This returns a nested ActiveSupport::OrderedOptions.new config
    def parse_ordered_options(obj)
      return obj unless obj.kind_of?(Hash)

      ActiveSupport::OrderedOptions.new.tap do |config|
        obj.each { |key, value| config[key] = parse_ordered_options(value) }
      end
    end

  end
end
