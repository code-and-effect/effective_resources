module Effective
  module Resources
    module Forms

      # Used by datatables
      def search_form_field(name, type = nil)
        case (type || sql_type(name))
        when :belongs_to
          { as: :select }.merge(associated_search_collection(belongs_to(name)))
        when :belongs_to_polymorphic
          { as: :grouped_select, polymorphic: true, collection: nil}
        when :has_and_belongs_to_many
          { as: :select }.merge(associated_search_collection(has_and_belongs_to_many(name)))
        when :has_many
          { as: :select, multiple: true }.merge(associated_search_collection(has_many(name)))
        when :has_one
          { as: :select, multiple: true }.merge(associated_search_collection(has_one(name)))
        when :effective_addresses
          { as: :string }
        when :effective_roles
          { as: :select, collection: EffectiveRoles.roles }
        when :effective_obfuscation
          { as: :effective_obfuscation }
        when :boolean
          { as: :boolean, collection: [['true', true], ['false', false]] }
        when :datetime
          { as: :datetime }
        when :date
          { as: :date }
        when :integer
          { as: :number }
        when :text
          { as: :text }
        else
          { as: :string }
        end
      end

      private

      def associated_search_collection(association, max_id = 1500)
        res = Effective::Resource.new(association)

        if res.max_id > max_id
          { as: :string }
        else
          if res.klass.unscoped.respond_to?(:datatables_filter)
            { collection: res.klass.datatables_filter.map { |obj| [obj.to_s, obj.to_param] } }
          elsif res.klass.unscoped.respond_to?(:sorted)
            { collection: res.klass.sorted.map { |obj| [obj.to_s, obj.to_param] } }
          else
            { collection: res.klass.all.map { |obj| [obj.to_s, obj.to_param] }.sort { |x, y| x[0] <=> y[0] } }
          end
        end
      end

    end
  end
end
