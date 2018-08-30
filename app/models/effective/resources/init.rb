module Effective
  module Resources
    module Init

      private

      def _initialize_input(input, namespace: nil)
        @model_klass = case input
        when String, Symbol
          _klass_by_name(input)
        when Class
          input
        when ActiveRecord::Relation
          input.klass
        when (ActiveRecord::Reflection::AbstractReflection rescue :nil)
          ((input.klass rescue nil).presence || _klass_by_name(input.class_name)) unless input.options[:polymorphic]
        when ActiveRecord::Reflection::MacroReflection
          ((input.klass rescue nil).presence || _klass_by_name(input.class_name)) unless input.options[:polymorphic]
        when ActionDispatch::Journey::Route
          @initialized_name = input.defaults[:controller]
          _klass_by_name(input.defaults[:controller])
        when nil    ; raise 'expected a string or class'
        else        ; _klass_by_name(input.class.name)
        end

        if namespace
          @namespaces = (namespace.kind_of?(String) ? namespace.split('/') : Array(namespace))
        end

        if input.kind_of?(ActiveRecord::Relation)
          @relation = input
        end

        if input.kind_of?(ActiveRecord::Reflection::MacroReflection) && input.scope
          @relation = klass.where(nil).merge(input.scope)
        end

        if klass && input.instance_of?(klass)
          @instance = input
        end
      end

      def _klass_by_name(input)
        input = input.to_s
        input = input[1..-1] if input.start_with?('/')

        names = input.split('/')

        0.upto(names.length-1) do |index|
          class_name = (names[index..-1].map { |name| name.classify } * '::')

          klass = class_name.safe_constantize

          if klass.present?
            @namespaces ||= names[0...index]
            @model_klass = klass
            return klass
          end
        end

        nil
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
