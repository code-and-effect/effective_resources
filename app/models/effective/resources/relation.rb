module Effective
  module Resources
    module Relation
      attr_reader :relation

      # When Effective::Resource is initialized with an ActiveRecord relation, the following
      # methods will be available to operate on that relation, and be chainable and such

      # name: sort by this column, or this relation
      # sort: when a symbol or boolean, this is the relation's column to sort by

      def order(name, direction = :asc, as: nil, sort: nil, sql_column: nil)
        raise 'expected relation to be present' unless relation

        sql_column ||= sql_column(name)
        sql_type = (as || sql_type(name))

        association = associated(name)
        sql_direction = sql_direction(direction)

        case sql_type
        when :belongs_to
          relation
            .order(postgres? ? "#{sql_column} IS NULL ASC" : "ISNULL(#{sql_column}) ASC")
            .order(order_by_associated_conditions(association, sort: sort, direction: direction))
        when :belongs_to_polymorphic
          relation
            .order("#{sql_column.sub('_id', '_type')} #{sql_direction}")
            .order("#{sql_column} #{sql_direction}")
        when :has_and_belongs_to_many, :has_many, :has_one
          relation
            .order(order_by_associated_conditions(association, sort: sort, direction: direction))
            .order("#{sql_column(klass.primary_key)} #{sql_direction}")
        when :effective_roles
          relation.order("#{sql_column(:roles_mask)} #{sql_direction}")
        when :string, :text
          relation
            .order((("ISNULL(#{sql_column}}), ") if mysql?).to_s + "#{sql_column}='' ASC, #{sql_column} #{sql_direction}" + (" NULLS LAST" if postgres?))
        else
          relation
            .order((("ISNULL(#{sql_column}}), ") if mysql?).to_s + "#{sql_column} #{sql_direction}" + (" NULLS LAST" if postgres?))
        end
      end

      def search(name, value, as: nil, fuzzy: true, sql_column: nil)
        raise 'expected relation to be present' unless relation

        sql_column ||= sql_column(name)
        sql_type = (as || sql_type(name))
        fuzzy = true unless fuzzy == false

        if ['SUM(', 'COUNT(', 'MAX(', 'MIN(', 'AVG('].any? { |str| sql_column.to_s.include?(str) }
          return relation.having("#{sql_column} = ?", value)
        end

        association = associated(name)
        term = Effective::Attribute.new(sql_type, klass: association.try(:klass) || klass).parse(value, name: name)

        case sql_type
        when :belongs_to, :has_and_belongs_to_many, :has_many, :has_one
          relation.where(search_by_associated_conditions(association, term, fuzzy: fuzzy))
        when :belongs_to_polymorphic
          (type, id) = term.split('_')
          relation.where("#{sql_column} = ?", id).where("#{sql_column.sub('_id', '_type')} = ?", type)
        when :effective_addresses
          raise 'not yet implemented'
        when :effective_obfuscation
          # If value == term, it's an invalid deobfuscated id
          relation.where("#{sql_column} = ?", (value == term ? 0 : term))
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
        when :decimal, :currency
          if fuzzy && (term.round(0) == term) && value.to_s.include?('.') == false
            if term < 0
              relation.where("#{sql_column} <= ? AND #{sql_column} > ?", term, term-1.0)
            else
              relation.where("#{sql_column} >= ? AND #{sql_column} < ?", term, term+1.0)
            end
          else
            relation.where("#{sql_column} = ?", term)
          end
        when :duration
          if fuzzy && (term % 60) == 0 && value.to_s.include?('m') == false
            if term < 0
              relation.where("#{sql_column} <= ? AND #{sql_column} > ?", term, term-60)
            else
              relation.where("#{sql_column} >= ? AND #{sql_column} < ?", term, term+60)
            end
          else
            relation.where("#{sql_column} = ?", term)
          end
        when :integer
          relation.where("#{sql_column} = ?", term)
        when :percentage
          relation.where("#{sql_column} = ?", term)
        when :price
          relation.where("#{sql_column} = ?", term)
        when :string, :text
          if fuzzy
            relation.where("#{sql_column} #{ilike} ?", "%#{term}%")
          else
            relation.where("#{sql_column} = ?", term)
          end
        else
          raise 'unsupported sql type'
        end
      end

      def search_any(value, columns: nil, fuzzy: nil)
        raise 'expected relation to be present' unless relation

        # Assume this is a set of IDs
        if value.kind_of?(Integer) || value.kind_of?(Array) || (value.to_i.to_s == value)
          return relation.where(klass.primary_key => value)
        end

        # Otherwise, we fall back to a string/text search of all columns
        columns = Array(columns || search_columns)
        fuzzy = true unless fuzzy == false

        conditions = (
          if fuzzy
            columns.map { |name| "#{sql_column(name)} #{ilike} :fuzzy" }
          else
            columns.map { |name| "#{sql_column(name)} = :value" }
          end
        ).join(' OR ')

        relation.where(conditions, fuzzy: "%#{value}%", value: value)
      end

      private

      def search_by_associated_conditions(association, value, fuzzy: nil)
        resource = Effective::Resource.new(association)

        # Search the target model for its matching records / keys
        relation = resource.search_any(value, fuzzy: fuzzy)

        if association.options[:as] # polymorphic
          relation = relation.where(association.type => klass.name)
        end

        # key: the id, or associated_id on my table
        # keys: the ids themselves as per the target table

        if association.macro == :belongs_to
          key = sql_column(association.foreign_key)
          keys = relation.pluck(association.klass.primary_key)
        elsif association.macro == :has_and_belongs_to_many
          key = sql_column(klass.primary_key)
          values = relation.pluck(association.source_reflection.klass.primary_key).uniq.compact

          keys = klass.joins(association.name)
            .where(association.name => { association.source_reflection.klass.primary_key => values })
            .pluck(klass.primary_key)
        elsif association.macro == :has_many && association.options[:through].present?
          key = sql_column(klass.primary_key)
          values = relation.pluck(association.source_reflection.klass.primary_key).uniq.compact

          keys = association.through_reflection.klass
            .where(association.source_reflection.foreign_key => values)
            .pluck(association.through_reflection.foreign_key)
        elsif association.macro == :has_many
          key = sql_column(klass.primary_key)
          keys = relation.pluck(association.foreign_key)
        elsif association.macro == :has_one
          key = sql_column(klass.primary_key)
          keys = relation.pluck(association.foreign_key)
        end

        "#{key} IN (#{(keys.uniq.compact.presence || [0]).join(',')})"
      end

      def order_by_associated_conditions(association, sort: nil, direction: :asc)
        resource = Effective::Resource.new(association)

        # Order the target model for its matching records / keys
        sort_column = (sort unless sort == true) || resource.sort_column

        relation = resource.relation.order("#{resource.sql_column(sort_column)} #{sql_direction(direction)}")

        if association.options[:as] # polymorphic
          relation = relation.where(association.type => klass.name)
        end

        # key: the id, or associated_id on my table
        # keys: the ids themselves as per the target table

        if association.macro == :belongs_to
          key = sql_column(association.foreign_key)
          keys = relation.pluck(association.klass.primary_key)
        elsif association.macro == :has_and_belongs_to_many
          key = sql_column(klass.primary_key)

          source = "#{association.join_table}.#{association.source_reflection.association_foreign_key}"
          values = relation.pluck(association.source_reflection.klass.primary_key).uniq.compact # The searched keys

          keys = klass.joins(association.name)
            .order(values.uniq.compact.map { |value| "#{source}=#{value} DESC" }.join(','))
            .pluck(klass.primary_key)
        elsif association.macro == :has_many && association.options[:through].present?
          key = sql_column(klass.primary_key)

          source = association.source_reflection.foreign_key
          values = relation.pluck(association.source_reflection.klass.primary_key).uniq.compact # The searched keys

          keys = association.through_reflection.klass
            .order(values.uniq.compact.map { |value| "#{source}=#{value} DESC" }.join(','))
            .pluck(association.through_reflection.foreign_key)
        elsif association.macro == :has_many
          key = sql_column(klass.primary_key)
          keys = relation.pluck(association.foreign_key)
        elsif association.macro == :has_one
          key = sql_column(klass.primary_key)
          keys = relation.pluck(association.foreign_key)
        end

        keys.uniq.compact.map { |value| "#{key}=#{value} DESC" }.join(',')
      end

    end
  end
end
