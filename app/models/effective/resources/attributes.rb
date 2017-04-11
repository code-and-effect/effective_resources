module Effective
  module Resources
    module Attributes

      def attributes
        (klass_attributes.presence || written_attributes.presence)
      end

      def attribute_names
        attributes.map { |attribute| attribute.name }
      end

      # All attributes from the klass, sorted as per attributes block.
      # Does not include :id, :created_at, :updated_at unless all is passed
      def klass_attributes(all: false)
        attributes = (klass.new().attributes rescue nil)
        return [] unless attributes

        names = attributes.keys - belong_tos.map { |reference| reference.foreign_key }
        names = names - [klass.primary_key, 'created_at', 'updated_at'] unless all

        attributes = names.map do |name|
          if klass.respond_to?(:column_for_attribute) # Rails 4+
            Effective::Attribute.new(name, klass.column_for_attribute(name).type)
          else
            Effective::Attribute.new(name, klass.columns_hash[name].type)
          end
        end

        sort_by_written_attributes(attributes)
      end

      def belong_tos_attributes
        belong_tos.map do |reference|
          unless reference.foreign_key == 'site_id' && klass.respond_to?(:acts_as_site_specific)
            Effective::Attribute.new(reference.foreign_key, :integer)
          end
        end.compact.sort
      end

      def written_attributes
        _initialize_written if @written_attributes.nil?
        @written_attributes
      end

      private

      def sort_by_written_attributes(attributes)
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




