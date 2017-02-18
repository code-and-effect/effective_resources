module Effective
  module Resources
    module Relation
      attr_reader :relation

      # When Effective::Resource is initialized with an ActiveRecord relation, the following
      # methods will be available to operate on that relation, and be chainable and such

      # name: sort by this column, or this relation
      # sort: when a symbol or boolean, this is the relation's column to sort by

      def order(name, direction: :asc, sort: nil, sql_column: nil)
        raise 'expected relation to be present' unless relation

        sql_column ||= sql_column(name)
        sql_direction = sql_direction(direction)

        association = associated(name)

        case association.try(:macro)
        when nil
          relation.order("#{sql_column} #{sql_direction}")
        when :belongs_to
          relation
            .order(postgres? ? "#{sql_column} IS NULL ASC" : "ISNULL(#{sql_column}) ASC")
            .order(order_by_associated(association, sort: sort, direction: direction))
        when :has_many
          relation
            .order(order_by_associated(association, sort: sort, direction: direction))
            .order("#{sql_column(klass.primary_key)} #{sql_direction}")
        when :belongs_to_polymorphic
          relation
            .order("#{sql_column.sub('_id', '_type')} #{sql_direction}")
            .order("#{sql_column} #{sql_direction}")
        else
          raise 'unsupported association macro'
        end
      end

      private

      def order_by_associated(association, sort: nil, direction: :asc)
        resource = Effective::Resource.new(association)

        key = nil
        association_key = nil

        case association.macro
        when :belongs_to
          key = sql_column(association.name)
          association_key = resource.klass.primary_key
        else
          key = sql_column(klass.primary_key)
          association_key = association.foreign_key
        end

        # If sort is nil/false/true we want to guess. Otherwise it's a symbol or string
        sort_column = (sort unless sort == true) || resource.sort_column

        scope = resource.klass.where(nil)
        scope = scope.merge(association.scope) if association.scope

        keys = scope.order("#{resource.sql_column(sort_column)} #{sql_direction(direction)}").pluck(association_key)

        keys.uniq.map { |value| "#{key}=#{value} DESC" }.join(',')
      end

    end
  end
end
