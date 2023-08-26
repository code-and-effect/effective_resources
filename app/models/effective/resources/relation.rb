# frozen_string_literal: true

module Effective
  module Resources
    module Relation
      TARGET_LIST_LIMIT = 1500
      TARGET_KEYS_LIMIT = 30000

      DO_NOT_SEARCH_EQUALS = ['unconfirmed_email', 'provider', 'secret', 'crypt', 'salt', 'uid', 'certificate', 'otp', 'ssn']
      DO_NOT_SEARCH_INCLUDE = ['password']
      DO_NOT_SEARCH_END_WITH = ['_url', '_param', '_token', '_type', '_id', '_key', '_ip']

      # This could be active_model? in which we just return the klass itself here
      # This value ends up being crud_controller resource_scope()
      def relation
        @relation ||= (klass.respond_to?(:where) ? klass.where(nil) : klass)
      end

      # When Effective::Resource is initialized with an ActiveRecord relation, the following
      # methods will be available to operate on that relation, and be chainable and such

      # name: sort by this column, or this relation
      # sort: when a symbol or boolean, this is the relation's column to sort by

      def order(name, direction = :asc, as: nil, sort: nil, sql_column: nil, limit: nil, reorder: false)
        raise 'expected relation to be present' unless relation

        sql_column ||= sql_column(name)
        sql_type = (as || sql_type(name))

        association = associated(name)
        sql_direction = sql_direction(direction)
        @relation = relation.reorder(nil) if reorder

        case sql_type
        when :belongs_to
          relation
            .order(order_by_associated_conditions(association, sort: sort, direction: direction, limit: limit))
        when :belongs_to_polymorphic
          relation
            .order(Arel.sql("#{sql_column}_type #{sql_direction}"))
            .order(Arel.sql("#{sql_column}_id #{sql_direction}"))
        when :has_and_belongs_to_many, :has_many, :has_one
          relation
            .order(order_by_associated_conditions(association, sort: sort, direction: direction, limit: limit))
            .order(Arel.sql("#{sql_column(klass.primary_key)} #{sql_direction}"))
        when :effective_addresses
          relation
            .order(order_by_associated_conditions(associated(:addresses), sort: sort, direction: direction, limit: limit))
            .order(Arel.sql("#{sql_column(klass.primary_key)} #{sql_direction}"))
        when :active_storage
          relation
            .send("with_attached_#{name}")
            .references("#{name}_attachment")
            .order(Arel.sql("active_storage_blobs.filename #{sql_direction}"))
        when :effective_roles
          relation
            .order(Arel.sql("#{sql_column(:roles_mask)} #{sql_direction}"))
        when :time
          relation
            .order(Arel.sql("EXTRACT(hour from #{sql_column}) #{sql_direction}, EXTRACT(minute from #{sql_column}) #{sql_direction}"))
        when :string, :text
          relation
            .order(Arel.sql(("ISNULL(#{sql_column}), " if mysql?).to_s + "#{sql_column}='' ASC, #{sql_column} #{sql_direction}" + (" NULLS LAST" if postgres?).to_s))
        when :date, :datetime
          relation
            .order(Arel.sql(("ISNULL(#{sql_column}), " if mysql?).to_s + "#{sql_column} #{sql_direction}" + (" NULLS LAST" if postgres?).to_s))
        else
          relation
            .order(Arel.sql("#{sql_column} #{sql_direction}"))
        end
      end

      def search(name, value, as: nil, column: nil, operation: nil)
        raise 'expected relation to be present' unless relation

        sql_as = (as || sql_type(name))
        sql_column = (column || sql_column(name))
        sql_operation = (operation || sql_operation(name, as: sql_as)).to_sym

        if ['SUM(', 'COUNT(', 'MAX(', 'MIN(', 'AVG('].any? { |str| sql_column.to_s.include?(str) }
          return relation.having("#{sql_column} = ?", value)
        end

        case sql_as
        when :belongs_to, :belongs_to_polymorphic, :has_and_belongs_to_many, :has_many, :has_one
          search_associated(name, value, as: sql_as, operation: sql_operation)
        else
          return relation.where(is_null(sql_column)) if value.to_s == 'nil'
          search_attribute(name, value, as: sql_as, operation: sql_operation, sql_column: sql_column)
        end
      end

      def search_associated(name, value, as:, operation:)
        reflection = associated(name)

        raise("expected to find #{relation.klass.name} #{name} reflection") unless reflection
        raise("unexpected search_associated operation #{operation || 'nil'}") unless [:eq, :matches, :does_not_match, :sql].include?(operation)

        # Parse values
        value_ids = value.kind_of?(Array) ? value : (value.to_s.split(/,|\s|\|/) - [nil, '', ' '])
        value_sql = Arel.sql(value) if value.kind_of?(String)

        # Foreign id and type
        foreign_id = reflection.foreign_key
        foreign_type = reflection.foreign_key.to_s.chomp('_id') + '_type'

        # belongs_to polymorphic
        retval = if as == :belongs_to_polymorphic
          (type, id) = value.to_s.split('_')

          if type.present? && id.present?  # This was from a polymorphic select
            case operation
            when :eq
              relation.where(foreign_type => type, foreign_id => id)
            when :matches
              relation.where(foreign_type => type, foreign_id => id)
            when :does_not_match
              relation.where.not(foreign_type => type, foreign_id => id)
            when :sql
              if (relation.where(value_sql).present? rescue :invalid) != :invalid
                relation.where(value_sql)
              else
                relation
              end
            end
          else # Maybe from a string field
            associated = relation.none

            relation.unscoped.distinct(foreign_type).pluck(foreign_type).each do |klass_name|
              next if klass_name.nil?

              resource = Effective::Resource.new(klass_name)
              next unless resource.klass.present?

              associated = associated.or(relation.where(foreign_id => resource.search_any(value), foreign_type => klass_name))
            end

            case operation
            when :eq
              relation.where(id: associated.select(:id))
            when :matches
              relation.where(id: associated.select(:id))
            when :does_not_match
              relation.where.not(id: associated.select(:id))
            when :sql
              if (relation.where(value_sql).present? rescue :invalid) != :invalid
                relation.where(value_sql)
              else
                relation
              end
            end
          end

        # belongs_to non-polymorphic
        elsif as == :belongs_to
          foreign_collection = reflection.klass.all
          foreign_collection = reflection.klass.where(foreign_type => relation.klass.name) if reflection.klass.new.respond_to?(foreign_type)

          case operation
          when :eq
            associated = foreign_collection.where(id: value_ids)
            relation.where(foreign_id => associated.select(:id))
          when :matches
            associated = Resource.new(foreign_collection).search_any(value)
            relation.where(foreign_id => associated.select(:id))
          when :does_not_match
            associated = Resource.new(foreign_collection).search_any(value)
            relation.where.not(foreign_id => associated.select(:id))
          when :sql
            if (foreign_collection.where(value_sql).present? rescue :invalid) != :invalid
              associated = foreign_collection.where(value_sql)
              relation.where(foreign_id => associated.select(:id))
            else
              relation
            end
          end

        # has_and_belongs_to_many
        elsif as == :has_and_belongs_to_many
          foreign_collection = reflection.source_reflection.klass.all

          habtm = foreign_collection.klass.reflect_on_all_associations.find { |ass| ass.macro == :has_and_belongs_to_many && ass.join_table == reflection.join_table }
          raise("expected a matching HABTM reflection") unless habtm

          case operation
          when :eq
            associated = foreign_collection.where(id: value_ids)
            relation.where(id: associated.joins(habtm.name).select(foreign_id))
          when :matches
            associated = Resource.new(foreign_collection).search_any(value)
            relation.where(id: associated.joins(habtm.name).select(foreign_id))
          when :does_not_match
            associated = Resource.new(foreign_collection).search_any(value)
            relation.where.not(id: associated.joins(habtm.name).select(foreign_id))
          when :sql
            if (foreign_collection.where(value_sql).present? rescue :invalid) != :invalid
              associated = foreign_collection.where(value_sql)
              relation.where(id: associated.joins(habtm.name).select(foreign_id))
            else
              relation
            end
          end

        # has_many through
        elsif reflection.options[:through].present?
          reflected_klass = if reflection.source_reflection.options[:polymorphic]
            reflection.klass
          else
            reflection.source_reflection.klass
          end

          reflected_id = if reflection.source_reflection.macro == :belongs_to
            reflection.source_reflection.foreign_key # to do check this
          else
            reflection.source_reflection.klass.primary_key # group_id
          end

          foreign_id = if reflection.through_reflection.macro == :belongs_to
            reflection.through_reflection.klass.primary_key # to do check this
          else
            reflection.through_reflection.foreign_key # user_id
          end

          # Build the through collection
          through = reflection.through_reflection.klass.all  # group mates

          if reflection.source_reflection.options[:polymorphic]
            through = through.where(reflection.source_reflection.foreign_type => reflected_klass.name)
          end

          # Search the associated class
          case operation
          when :eq
            associated = through.where(reflected_id => value_ids)
            relation.where(id: associated.select(foreign_id))
          when :matches
            reflected = Resource.new(reflected_klass).search_any(value)
            associated = through.where(reflected_id => reflected)
            relation.where(id: associated.select(foreign_id))
          when :does_not_match
            reflected = Resource.new(reflected_klass).search_any(value)
            associated = through.where(reflected_id => reflected)
            relation.where.not(id: associated.select(foreign_id))
          when :sql
            if (reflected_klass.where(value_sql).present? rescue :invalid) != :invalid
              reflected = reflected_klass.where(value_sql)
              associated = through.where(reflected_id => reflected)
              relation.where(id: associated.select(foreign_id))
            else
              relation
            end
          end

        # has_many and has_one
        elsif (as == :has_many || as == :has_one)
          foreign_collection = reflection.klass.all
          foreign_collection = reflection.klass.where(foreign_type => relation.klass.name) if reflection.klass.new.respond_to?(foreign_type)

          case operation
          when :eq
            associated = foreign_collection.where(id: value_ids)
            relation.where(id: associated.select(foreign_id))
          when :matches
            associated = Resource.new(foreign_collection).search_any(value)
            relation.where(id: associated.select(foreign_id))
          when :does_not_match
            associated = Resource.new(foreign_collection).search_any(value)
            relation.where.not(id: associated.select(foreign_id))
          when :sql
            if (foreign_collection.where(value_sql).present? rescue :invalid) != :invalid
              associated = foreign_collection.where(value_sql)
              relation.where(id: associated.select(foreign_id))
            else
              relation
            end
          end
        end

        retval || raise("unable to search associated #{as} #{operation} #{name} for #{value}")
      end

      def search_attribute(name, value, as:, operation:, sql_column:)
        raise 'expected relation to be present' unless relation

        attribute = relation.arel_table[name]

        # Normalize the term.
        # If you pass an email attribute it can return nil so we return the full value
        term = Attribute.new(as).parse(value, name: name)
        term = value if term.nil?

        # If using the joined syntax from datatables
        joined = (sql_column.to_s.split('.').first.to_s.include?(relation.arel_table.name) == false)

        searched = case as
          when :active_storage
            relation.send("with_attached_#{name}").references("#{name}_attachment")
              .where(ActiveStorage::Blob.arel_table[:filename].matches("%#{term}%"))

          when :date, :datetime
            if value.kind_of?(String)
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

              if as == :date
                relation.where("#{sql_column} >= ? AND #{sql_column} < ?", term.to_date, (end_at + 1.day).to_date)
              else
                relation.where("#{sql_column} >= ? AND #{sql_column} <= ?", term, end_at)
              end
            elsif value.respond_to?(:strftime) && operation == :eq
              relation.where(attribute.matches(value))
            end

          when :effective_obfuscation
            term = Attribute.new(as, klass: (associated(name).try(:klass) || klass)).parse(value, name: name)
            relation.where(attribute.eq((value == term ? 0 : term)))

          when :effective_addresses
            association = associated(name)
            associated = Resource.new(association).search_any(value)
            relation.where(id: associated.where(addressable_type: klass.name).select(:addressable_id))

          when :effective_roles
            relation.with_role(term)

          when :time
            timed = relation.where("EXTRACT(hour from #{sql_column}) = ?", term.utc.hour)
            timed = timed.where("EXTRACT(minute from #{sql_column}) = ?", term.utc.min) if term.min > 0
            timed
        end

        return searched if searched

        # Simple operation search
        # The Arel operator eq and matches bug out with serialized Array columns. So we avoid for datatables usage.

        case operation
          when :eq then relation.where("#{sql_column} = ?", term)
          when :matches then search_columns_by_ilike_term(relation, term, columns: (sql_column.presence || name))
          when :not_eq then relation.where(attribute.not_eq(term))
          when :does_not_match then relation.where(attribute.does_not_match("%#{term}%"))
          when :starts_with then relation.where(attribute.matches("#{term}%"))
          when :ends_with then relation.where(attribute.matches("%#{term}"))
          when :gt then relation.where(attribute.gt(term))
          when :gteq then relation.where(attribute.gteq(term))
          when :lt then relation.where(attribute.lt(term))
          when :lteq then relation.where(attribute.lteq(term))
          when :days_ago_eq
            date = Time.zone.now.advance(days: -term.to_i)
            relation.where("#{sql_column} >= ? AND #{sql_column} <= ?", date.beginning_of_day, date.end_of_day)
          when :days_ago_lteq # 30 days or less ago.
            date = Time.zone.now.advance(days: -term.to_i)
            relation.where("#{sql_column} >= ?", date)
          when :days_ago_gteq # 30 days or more ago
            date = Time.zone.now.advance(days: -term.to_i)
            relation.where("#{sql_column} <= ?", date)
          else raise("Unexpected operation: #{operation}")
        end
      end

      def search_any(value, columns: nil, fuzzy: nil)
        raise 'expected relation to be present' unless relation

        # Assume this is a set of IDs
        if value.kind_of?(Integer) || value.kind_of?(Array) || (value.to_i.to_s == value)
          return relation.where(klass.primary_key => value)
        end

        # If the user specifies columns. Filter out invalid ones for this klass
        if columns.present?
          columns = Array(columns).map(&:to_s) - [nil, '']
          columns = (columns & search_columns)
        end

        # Otherwise, we fall back to a string/text search of all columns
        columns = Array(columns || search_columns).reject do |column|
          DO_NOT_SEARCH_EQUALS.any? { |value| column == value } ||
          DO_NOT_SEARCH_INCLUDE.any? { |value| column.include?(value) } ||
          DO_NOT_SEARCH_END_WITH.any? { |value| column.end_with?(value) }
        end

        return relation.none() if columns.blank?
        search_columns_by_ilike_term(relation, value, columns: columns, fuzzy: fuzzy)
      end

      private

      def search_columns_by_ilike_term(collection, value, columns:, fuzzy: nil)
        return collection if value.blank?

        value = value.to_s

        raise('unsupported OR and AND syntax') if value.include?(' OR ') && value.include?(' AND ')
        raise('expected columns') unless columns.present?

        terms = []
        join = ''

        if value.include?(' OR ')
          terms = value.split(' OR ')
          join = ' OR '
        elsif value.include?(' AND ')
          terms = value.split(' AND ')
          join = ' AND '
        else
          terms = value.split(' ')
          join = ' AND '
        end

        terms = (terms - [nil, '', ' ']).map(&:strip)
        columns = Array(columns)
        fuzzy = true if fuzzy.nil?

        terms = terms.inject({}) do |hash, term|
          hash["term_#{hash.length}".to_sym] = (fuzzy ? "%#{term}%" : term); hash
        end

        # Do any of these columns contain all the terms?
        conditions = columns.map do |name|
          column = (name.to_s.include?('.') ? name : sql_column(name))
          raise("expected an sql column for #{name}") if column.blank?

          keys = terms.keys.map { |key| (fuzzy ? "#{column} #{ilike} :#{key}" : "#{column} = :#{key}") }
          '(' + keys.join(' AND ') + ')'
        end.join(' OR ')

        # Do the search
       collection.where(conditions, terms)
      end

      def order_by_associated_conditions(association, sort: nil, direction: :asc, limit: nil)
        resource = Effective::Resource.new(association)

        # Order the target model for its matching records / keys
        sort_column = (sort unless sort == true) || resource.sort_column

        relation = resource.order(sort_column, direction, limit: limit, reorder: true)

        if association.options[:as] # polymorphic
          relation = relation.where(association.type => klass.name)
        end

        # key: the id, or associated_id on my table
        # keys: the ids themselves as per the target table

        if association.macro == :belongs_to && association.options[:polymorphic]
          key = sql_column(association.foreign_key)
          keys = relation.pluck((relation.klass.primary_key rescue nil))
        elsif association.macro == :belongs_to
          key = sql_column(association.foreign_key)
          keys = relation.pluck(association.klass.primary_key)
        elsif association.macro == :has_and_belongs_to_many
          key = sql_column(klass.primary_key)

          source = "#{association.join_table}.#{association.source_reflection.association_foreign_key}"
          values = relation.limit(TARGET_LIST_LIMIT).pluck(association.source_reflection.klass.primary_key).uniq.compact # The searched keys

          keys = klass.joins(association.name)
            .order(order_by_array_position(values, source))
            .pluck(klass.primary_key)
        elsif association.macro == :has_many && association.options[:through].present?
          key = sql_column(klass.primary_key)

          source = association.source_reflection.foreign_key
          values = relation.limit(TARGET_LIST_LIMIT).pluck(association.source_reflection.klass.primary_key).uniq.compact # The searched keys

          keys = association.through_reflection.klass
            .order(order_by_array_position(values, source))
            .pluck(association.through_reflection.foreign_key)
        elsif association.macro == :has_many
          key = sql_column(klass.primary_key)
          keys = relation.pluck(association.foreign_key)
        elsif association.macro == :has_one
          key = sql_column(klass.primary_key)
          keys = relation.pluck(association.foreign_key)
        end

        order_by_array_position(keys, key)
      end

      def order_by_array_position(keys, field)
        keys = Array(keys).uniq.compact.presence || [0]

        if postgres?
          Arel.sql("array_position(ARRAY[#{keys.first(TARGET_KEYS_LIMIT).join(',')}]::text::int[], #{field}::int)")
        else
          Arel.sql(keys.first(TARGET_LIST_LIMIT).map { |value| "#{field}=#{value} DESC" }.join(','))
        end

      end

    end
  end
end
