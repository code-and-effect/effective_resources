module Effective
  module Resources
    module Init

      private

      def _initialize_input(input, namespace: nil, relation: nil)
        @initialized_name = input
        @model_klass = (relation ? _klass_by_input(relation) : _klass_by_input(input))

        # Consider controller_name
        if @model_klass && input.kind_of?(String) && namespace.blank?
          @controller_path = input
        end

        # Consider namespaces
        if namespace
          @namespaces = (namespace.kind_of?(String) ? namespace.split('/') : Array(namespace))
        end

        if input.kind_of?(Array) && @namespaces.blank?
          @namespaces = input[0...-1].map { |input| input.to_s.presence }.compact
        end

        # Consider relation
        if relation.kind_of?(ActiveRecord::Relation)
          @relation ||= relation
        end

        if input.kind_of?(ActiveRecord::Relation)
          @relation ||= input
        end

        if input.kind_of?(ActiveRecord::Reflection::MacroReflection) && input.scope
          @relation ||= @model_klass.where(nil).merge(input.scope)
        end

        # Consider instance
        if @model_klass && input.instance_of?(@model_klass)
          @instance ||= input
        end

        if @model_klass && input.kind_of?(Array) && input.last.instance_of?(@model_klass)
          @instance ||= input.last
        end
      end

      def _klass_by_input(input)
        case input
        when Array
          _klass_by_input(input.last)
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
      end


      # 'acpa/admin/shirts'
      def _klass_by_name(input)
        input = input.to_s
        input = input[1..-1] if input.start_with?('/')
        names = input.split(%r{\/|::})

        # Classify based on namespace
        # acpa/admin/shirts
        (names.length).downto(1).each do |n|
          names.combination(n).to_a.each do |pieces|
            klass_pieces = pieces.map { |piece| piece.classify } * '::'
            klass = klass_pieces.safe_constantize

            if klass.present? && klass.class != Module
              @namespaces ||= (names - pieces)
              @model_klass = klass
              return klass
            end
          end
        end

        # Crazy effective engine.
        if names[0] == 'admin'
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
