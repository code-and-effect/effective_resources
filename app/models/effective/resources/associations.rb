module Effective
  module Resources
    module Associations

      def belong_tos
        return [] unless klass.respond_to?(:reflect_on_all_associations)

        @belong_tos ||= klass.reflect_on_all_associations(:belongs_to)
      end

      def nested_resources
        return [] unless klass.respond_to?(:reflect_on_all_autosave_associations)

        @nested_resources ||= klass.reflect_on_all_autosave_associations.select { |reference| reference.macro == :has_many }
      end

      def has_manys
      end

      def scopes
      end

    end
  end
end




