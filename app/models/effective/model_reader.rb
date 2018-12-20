module Effective
  class ModelReader
    DATATYPES = [:binary, :boolean, :date, :datetime, :decimal, :float, :hstore, :inet, :integer, :string, :text, :permitted_param]

    attr_reader :attributes

    def initialize(&block)
      @attributes = {}
    end

    def read(&block)
      instance_exec(&block)
    end

    def method_missing(m, *args, &block)
      if m == :timestamps
        attributes[:created_at] = [:datetime]
        attributes[:updated_at] = [:datetime]
        return
      end

      # Not really an attribute, just a permitted param.
      # something permitted: true
      if args.first.kind_of?(Hash) && args.first.key?(:permitted)
        args.unshift(:permitted_param)
      end

      # Specifying permitted param attributes
      # invitation [:name, :email], permitted: true
      if args.first.kind_of?(Array)
        options = args.find { |arg| arg.kind_of?(Hash) } || { permitted: true }
        args = [:permitted_param, options.merge(permitted_attributes: args.first)]
      end

      unless DATATYPES.include?(args.first)
        raise "expected first argument to be a datatype. Try name :string"
      end

      attributes[m] = args
    end

  end
end
