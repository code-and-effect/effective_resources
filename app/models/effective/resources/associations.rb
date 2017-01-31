module Effective
  module Resources
    module Associations

      def belong_tos
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        @belong_tos ||= klass.reflect_on_all_associations(:belongs_to)
      end

      def has_ones
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        @has_ones ||= klass.reflect_on_all_associations(:has_one)
      end

      def has_manys
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        @has_manys ||= klass.reflect_on_all_associations(:has_many).reject { |association| association.options[:autosave] }
      end

      def nested_resources
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        @nested_resources ||= klass.reflect_on_all_associations(:has_many).select { |association| association.options[:autosave] }
      end

      def scopes
      end

    end
  end
end




