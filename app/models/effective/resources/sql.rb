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

      def max_id
        @max_id ||= klass.maximum(klass.primary_key).to_i
      end

      def sql_column(name)
        column = column(name)
        return nil unless table && column

        [klass.connection.quote_table_name(table.name), klass.connection.quote_column_name(column.name)].join('.')
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

      def table
        klass.unscoped.table
      end

    end
  end
end
