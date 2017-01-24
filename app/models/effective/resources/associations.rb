module Effective
  module Resources
    module Associations

      def belongs_tos
        @belongs_tos ||= klass.reflect_on_all_associations(:belongs_to)
      end

      def has_manys
      end

      def scopes
      end

    end
  end
end




