module Effective
  module Resources
    module Init

      private

      def _initialize(obj)
        @input_name = _initialize_input_name(obj)
        _initialize_names(@input_name)

        @relation = _initialize_relation(obj)
        @instance = obj if (klass && obj.instance_of?(klass))
      end

      def _initialize_input_name(input)
        case input
        when String ; input.start_with?('/') ? input[1..-1] : input
        when Symbol ; input
        when Class  ; input.name
        when ActiveRecord::Relation
          input.klass
        when ActiveRecord::Reflection::AbstractReflection
          @model_klass = input.klass unless input.options[:polymorphic]
          input.name
        when ActionDispatch::Journey::Route
          input.defaults[:controller]
        when nil    ; raise 'expected a string or class'
        else        ; input.class.name
        end.to_s.underscore
      end

      def _initialize_names(input)
        names = input.split('/')

        0.upto(names.length-1) do |index|
          class_name = (names[index..-1].map { |name| name.classify } * '::')

          if (@model_klass = class_name.safe_constantize).present?
            @class_name = class_name
            @namespaces = names[0...index]
            break
          end
        end
      end

      def _initialize_relation(input)
        return nil unless klass && klass.respond_to?(:where)

        case input
        when ActiveRecord::Relation
          input
        when ActiveRecord::Reflection::AbstractReflection
          klass.where(nil).merge(input.scope) if input.scope
        end || klass.where(nil)
      end

      # Lazy initialized
      def _initialize_written
        @written_attributes = []
        @written_belong_tos = []
        @written_scopes = []

        return unless File.exists?(model_file)

        Effective::CodeReader.new(model_file) do |reader|
          first = reader.index { |line| line == '# Attributes' }
          last = reader.index(from: first) { |line| line.start_with?('#') == false && line.length > 0 } if first

          if first && last
            @written_attributes = reader.select(from: first+1, to: last-1).map do |line|
              Effective::Attribute.parse_written(line).presence
            end.compact
          end

          @written_belong_tos = reader.select { |line| line.start_with?('belongs_to ') }.map do |line|
            line.scan(/belongs_to\s+:(\w+)/).flatten.first
          end

          @written_scopes = reader.select { |line| line.start_with?('scope ') }.map do |line|
            line.scan(/scope\s+:(\w+)/).flatten.first
          end
        end
      end

    end
  end
end
