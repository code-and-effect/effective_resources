module Effective
  module Resources
    module Forms

      # Used by datatables
      def search_form_field(name, type = nil)
        case (type || sql_type(name))
        when :belongs_to
          { as: :select }.merge(search_form_field_collection(belongs_to(name)))
        when :belongs_to_polymorphic
          #{ as: :select, grouped: true, polymorphic: true, collection: nil}
          { as: :string }
        when :has_and_belongs_to_many
          { as: :select }.merge(search_form_field_collection(has_and_belongs_to_many(name)))
        when :has_many
          { as: :select, multiple: true }.merge(search_form_field_collection(has_many(name)))
        when :has_one
          { as: :select, multiple: true }.merge(search_form_field_collection(has_one(name)))
        when :effective_addresses
          { as: :string }
        when :effective_roles
          { as: :select, collection: EffectiveRoles.roles }
        when :effective_obfuscation
          { as: :effective_obfuscation }
        when :boolean
          { as: :boolean, collection: [['Yes', true], ['No', false]] }
        when :datetime
          { as: :datetime }
        when :date
          { as: :date }
        when :integer
          { as: :number }
        when :text
          { as: :text }
        when ActiveRecord::Base
          { as: :select }.merge(Effective::Resource.new(type).search_form_field_collection)
        else
          name = name.to_s

          # If the method is named :status, and there is a Class::STATUSES
          if ((klass || NilClass).const_defined?(name.pluralize.upcase) rescue false)
            { as: :select, collection: klass.const_get(name.pluralize.upcase) }
          elsif ((klass || NilClass).const_defined?(name.singularize.upcase) rescue false)
            { as: :select, collection: klass.const_get(name.singularize.upcase) }
          else
            { as: :string }
          end
        end
      end

      def search_form_field_collection(association = nil, max_id = 1000)
        res = (association.nil? ? self : Effective::Resource.new(association))

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
