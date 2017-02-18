module Effective
  module Resources
    module Sql

      def column(name)
        name = name.to_s
        columns.find { |col| col.name == name || (belongs_to(name) && col.name == belongs_to(name).foreign_key) }
      end

      def columns
        klass.columns
      end

      def column_names
        @column_names ||= columns.map { |col| col.name }
      end

      def table
        klass.unscoped.table
      end

      def max_id
        @max_id ||= klass.maximum(klass.primary_key).to_i
      end

      def sql_column(name)
        column = column(name)
        return nil unless table && column

        [klass.connection.quote_table_name(table.name), klass.connection.quote_column_name(column.name)].join('.')
      end

      def sql_direction(name)
        name.to_s.downcase == 'desc' ? 'DESC' : 'ASC'
      end

      # This is for EffectiveDatatables (col as:)
      def sql_type(name)
        name = name.to_s

        if belongs_to_polymorphic(name)
          :belongs_to_polymorphic
        elsif belongs_to(name)
          :belongs_to
        elsif has_and_belongs_to_many(name)
          :has_and_belongs_to_many
        elsif has_many(name)
          :has_many
        elsif has_one(name)
          :has_one
        elsif name.end_with?('_address') && defined?(EffectiveAddresses) && instance.respond_to?(:effective_addresses)
          :effective_addresses
        elsif name == 'id' && defined?(EffectiveObfuscation) && klass.respond_to?(:deobfuscate)
          :effective_obfuscation
        elsif name == 'roles' && defined?(EffectiveRoles) && klass.respond_to?(:with_role)
          :effective_roles
        elsif (column = column(name))
          column.type
        elsif name.ends_with?('_id')
          :integer
        else
          :string
        end
      end

      def search_field(name, type = nil)
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

      # This tries to figure out the column we should order this collection by.
      # Whatever would match up with the .to_s
      def sort_column
        ['name', 'title', 'label', 'first_name', 'subject', 'description', 'email'].each do |name|
          return name if column_names.include?(name)
        end

        klass.primary_key
      end

      def order_by_associated_conditions(name, sort: nil, direction: :asc)
        association = associated(name)
        resource = Effective::Resource.new(association)

        key = nil
        association_key = nil

        case association.macro
        when :belongs_to
          key = sql_column(name)
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

      private

      def associated_search_collection(association, max_id = 500)
        res = Effective::Resource.new(association)

        if res.max_id > max_id
          { as: :string }
        else
          if res.klass.unscoped.respond_to?(:datatables_filter)
            { collection: res.klass.datatables_filter }
          elsif res.klass.unscoped.respond_to?(:sorted)
            { collection: res.klass.sorted }
          else
            { collection: res.klass.all.map { |obj| [obj.to_s, obj.to_param] }.sort { |x, y| x[0] <=> y[0] } }
          end
        end
      end

    end
  end
end
