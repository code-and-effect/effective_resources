module Effective
  module Resources
    module Associations

      def macros
        [:belongs_to, :belongs_to_polymorphic, :has_many, :has_and_belongs_to_many, :has_one]
      end

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
        @has_manys ||= klass.reflect_on_all_associations(:has_many).reject { |ass| ass.options[:autosave] }
      end

      def has_and_belongs_to_manys
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        @has_and_belongs_to_manys ||= klass.reflect_on_all_associations(:has_and_belongs_to_many)
      end

      def nested_resources
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        @nested_resources ||= klass.reflect_on_all_associations(:has_many).select { |ass| ass.options[:autosave] }
      end

      def scopes
      end

      def associated(name)
        name = (name.to_s.end_with?('_id') ? name.to_s[0...-3] : name).to_sym
        klass.reflect_on_all_associations.find { |ass| ass.name == name }
      end

      def belongs_to(name)
        name = (name.to_s.end_with?('_id') ? name.to_s[0...-3] : name).to_sym
        belong_tos.find { |ass| ass.name == name }
      end

      def belongs_to_polymorphic(name)
        name = (name.to_s.end_with?('_id') ? name.to_s[0...-3] : name).to_sym
        belong_tos.find { |ass| ass.name == name && ass.options[:polymorphic] }
      end

      def has_and_belongs_to_many(name)
        name = name.to_sym
        has_and_belongs_to_manys.find { |ass| ass.name == name }
      end

      def has_many(name)
        name = name.to_sym
        (has_manys + nested_resources).find { |ass| ass.name == name }
      end

      def has_one(name)
        name = name.to_sym
        has_ones.find { |ho| ass.name == name }
      end

      def nested_resource(name)
        name = name.to_sym
        nested_resources.find { |ass| ass.name == name }
      end

    end
  end
end




