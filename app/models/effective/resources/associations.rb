module Effective
  module Resources
    module Associations

      def belongs_tos
        # @belongs_tos ||= (
        #   (class_name.constantize.reflect_on_all_associations(:belongs_to) rescue []).map { |a| a.foreign_key }
        # )
      end

      def has_manys
      end

      def scopes
      end

    end
  end
end




