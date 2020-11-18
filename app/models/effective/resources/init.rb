module Effective
  module Resources
    module Init

      private

      def _initialize_input(input, namespace: nil, engine_name: nil)
        @initialized_name = input

        @engine_name = engine_name

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

        # Crazy classify
        0.upto(names.length-1) do |index|
          class_name = names[index..-1].map { |name| name.classify } * '::'
          klass = class_name.safe_constantize

          if klass.blank? && index > 0
            class_name = (names[0..index-1].map { |name| name.classify.pluralize } + names[index..-1].map { |name| name.classify }) * '::'
            klass = class_name.safe_constantize
          end

          if klass.present?
            @namespaces ||= names[0...index]
            @model_klass = klass
            return klass
          end
        end

        # Crazy engine
        if engine_name.present? && names[0] == 'admin'
          class_name = (['effective'] + names[1..-1]).map { |name| name.classify } * '::'
          klass = class_name.safe_constantize

          if klass.present?
            @namespaces ||= names[0...-1]
            @model_klass = klass
            return klass
          end
        end

        nil
      end

    end
  end
end
