module Effective
  class Attribute
    attr_accessor :name, :type

    REGEX = /^\W*(\w+)\W*:(\w+)/

    def self.parse(input)
      input = input.to_s

      if (scanned = input.scan(REGEX).first).present?
        new(*scanned)
      elsif input.start_with?('#')
        new(nil)
      else
        new(input)
      end
    end

    def initialize(name, type = nil, options = {})
      @name = name.to_s
      @type = (type.presence || :string).to_sym
      @options = options
    end

    def to_s
      name
    end

    def field_type
      @field_type ||= case type
        when :integer              then :number_field
        when :float, :decimal      then :text_field
        when :time                 then :time_select
        when :datetime, :timestamp then :datetime_select
        when :date                 then :date_select
        when :text                 then :text_area
        when :boolean              then :check_box
        else :text_field
      end
    end

    def present?
      name.present?
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
