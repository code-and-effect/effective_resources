module Effective
  class ModelReader
    DATATYPES = [:binary, :boolean, :date, :datetime, :decimal, :hstore, :inet, :integer, :string, :text]

    attr_reader :attributes

    def initialize(&block)
      @attributes = {}
      instance_exec(&block)
    end

    def method_missing(m, *args, &block)
      raise "#{m} has already been defined" if attributes[m]

      if m == :timestamps
        attributes[:created_at] = [:datetime]
        attributes[:updated_at] = [:datetime]
        return
      end

      unless DATATYPES.include?(args.first)
        raise "expected first argument to be a datatype. Try name :string"
      end

      attributes[m] = args
    end

  end
end
