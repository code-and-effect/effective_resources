module Effective
  module Resources
    module Attributes

      def attributes
        klass_attributes.presence || written_attributes.presence
      end

      # All attributes from the klass, sorted as per attributes block.
      # Does not include :id, :created_at, :updated_at
      def klass_attributes
        attributes = (klass.new().attributes rescue nil)
        return [] unless attributes

        attributes = (attributes.keys - [klass.primary_key, 'created_at', 'updated_at']).map do |att|
          if klass.respond_to?(:column_for_attribute) # Rails 4+
            Effective::Attribute.new(att, klass.column_for_attribute(att).try(:type))
          else
            Effective::Attribute.new(att, klass.columns_hash[att].try(:type))
          end
        end

        sort(attributes)
      end

      def belong_tos_attributes
        belong_tos.map { |reference| Effective::Attribute.new(reference.foreign_key, :integer) }.sort
      end

      def written_attributes
        _initialize_written if @written_attributes.nil?
        @written_attributes
      end

      private

      def sort(attributes)
        attributes.sort do |a, b|
          index = nil

          index ||= if written_attributes.include?(a) && written_attributes.include?(b)
            written_attributes.index(a) <=> written_attributes.index(b)
          elsif written_attributes.include?(a) && !written_attributes.include?(b)
            -1
          elsif !written_attributes.include?(a) && written_attributes.include?(b)
            1
          end

          index || a <=> b
        end
      end

    end
  end
end




