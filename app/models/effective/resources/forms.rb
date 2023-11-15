# frozen_string_literal: true

module Effective
  module Resources
    module Forms

      # Used by datatables
      def search_form_field(name, type = nil)
        case (type || sql_type(name))
        when :belongs_to
          { as: :select }.merge(search_form_field_collection(belongs_to(name)))

        when :belongs_to_polymorphic
          constant_pluralized = name.to_s.upcase
          constant = name.to_s.pluralize.upcase

          collection = nil

          if klass.respond_to?(:name)
            collection ||= (klass.const_get(constant) rescue nil) if defined?("#{klass.name}::#{constant}")
            collection ||= (klass.const_get(constant_pluralized) rescue nil) if defined?("#{klass.name}::#{constant_pluralized}")
          end

          if collection.present?
            { as: :select, polymorphic: true, collection: (collection || []) }
          else
            { as: :string }
          end
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
        when :time
          { as: :time }
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

      # Load the limit records + 1. If there are all there, return as: :string
      # Otherwise return an Array of the processed results ready for a select field
      # Only hit the database once
      def search_form_field_collection(association = nil, limit: 100)
        res = (association.nil? ? self : Effective::Resource.new(association))

        # Return string if this isnt a relational thing
        klass = res.klass
        return { as: :string } unless klass.respond_to?(:unscoped)

        # Default scope
        scope = res.klass.unscoped

        scope = if scope.respond_to?(:datatables_scope)
          scope.datatables_scope
        elsif scope.respond_to?(:datatables_filter)
          scope.datatables_filter
        elsif scope.respond_to?(:sorted)
          scope.sorted
        else
          scope
        end

        scope = scope.deep if scope.respond_to?(:deep)
        scope = scope.unarchived if scope.respond_to?(:unarchived)

        # Now that we have the scope figured out let's pull the limit number of records into an Array
        # If there are more than the limit, return as: :string
        resources = scope.limit(limit).to_a
        return { as: :string } unless resources.length < limit

        # Otherwise there are less than the limit, so we can use a collection select
        {
          collection: resources.map { |obj| [obj.to_s, obj.id] }
        }
      end

    end
  end
end
