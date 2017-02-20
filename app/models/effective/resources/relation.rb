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
        when :belongs_to_polymorphic
          relation
            .order("#{sql_column.sub('_id', '_type')} #{sql_direction}")
            .order("#{sql_column} #{sql_direction}")
        when :has_many
          relation
            .order(order_by_associated(association, sort: sort, direction: direction))
            .order("#{sql_column(klass.primary_key)} #{sql_direction}")
        else
          raise 'unsupported association macro'
        end
      end

      def search(name, value, as: nil, fuzzy: true, sql_column: nil)
        raise 'expected relation to be present' unless relation

        if ['SUM(', 'COUNT(', 'MAX(', 'MIN(', 'AVG('].any? { |str| sql_column.to_s.include?(str) }
          return relation.having("#{sql_column} = ?", value)
        end

        sql_column ||= sql_column(name)
        sql_type = (as || sql_type(name))
        fuzzy = true unless fuzzy == false

        association = associated(name)
        term = Effective::Attribute.new(sql_type).parse(value, name: name)

        case sql_type
        when :belongs_to
        when :belongs_to_polymorphic
        when :has_many
        when :has_and_belongs_to_many
        when :effective_obfuscation
        when :effective_address
        when :effective_roles
          relation.with_role(term)
        when :boolean
          relation.where("#{sql_column} = ?", term)
        when :datetime, :date
          end_at = (
            case (value.to_s.scan(/(\d+)/).flatten).length
            when 1 ; term.end_of_year     # Year
            when 2 ; term.end_of_month    # Year-Month
            when 3 ; term.end_of_day      # Year-Month-Day
            when 4 ; term.end_of_hour     # Year-Month-Day Hour
            when 5 ; term.end_of_minute   # Year-Month-Day Hour-Minute
            when 6 ; term + 1.second      # Year-Month-Day Hour-Minute-Second
            else term
            end
          )
          relation.where("#{sql_column} >= ? AND #{sql_column} <= ?", term, end_at)
        when :decimal
          relation.where("#{sql_column} = ?", term)
        when :integer
          relation.where("#{sql_column} = ?", term)
        when :price
          relation.where("#{sql_column} = ?", term)
        when :string, :text
          if term == 'nil'
            relation.where("#{sql_column} = ? OR #{sql_column} IS NULL", term)
          elsif fuzzy
            relation.where("#{sql_column} #{ilike} ?", "%#{term}%")
          else
            relation.where("#{sql_column} = ?", term)
          end
        else
          raise 'unsupported sql type'
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
