module Effective
  module Resources
    module Init

      private

      def _initialize(input, namespace: nil)
        @namespaces = (namespace.kind_of?(String) ? namespace.split('/') : Array(namespace)) if namespace

        @model_klass = case input
        when String, Symbol
          _klass_by_name(input)
        when ActiveRecord::Relation
          input.klass
        when ActiveRecord::Reflection::MacroReflection
          input.klass unless input.options[:polymorphic]
        when ActionDispatch::Journey::Route
          _klass_by_name(input.defaults[:controller])
        when Class
          input
        when nil    ; raise 'expected a string or class'
        else        ; _klass_by_name(input.class.name)
        end

        @relation = _initialize_relation(input)
        @instance = input if (klass && input.instance_of?(klass))
      end

      def _klass_by_name(input)
        input = input.to_s
        input = input[1..-1] if input.start_with?('/')

        names = input.split('/')

        0.upto(names.length-1) do |index|
          class_name = (names[index..-1].map { |name| name.classify } * '::')
          klass = (class_name.safe_constantize rescue nil)

          if klass.present?
            @namespaces = names[0...index]
            @model_klass = klass
            return klass
          end
        end
      end

      def _initialize_relation(input)
        return nil unless klass && klass.respond_to?(:where)

        case input
        when ActiveRecord::Relation
          input
        when ActiveRecord::Reflection::MacroReflection
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
