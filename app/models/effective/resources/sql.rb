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
        binding.pry

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

      # This tries to figure out the column we should order this collection by.
      # Whatever would match up with the .to_s
      def sort_column
        ['name', 'title', 'label', 'first_name', 'subject', 'description', 'email'].each do |name|
          return name if column_names.include?(name)
        end

        klass.primary_key
      end

      # Any string or text columns
      # TODO: filter out _type columns for polymorphic
      def search_columns
        columns.map { |column| column.name if [:string, :text].include?(column.type) }.compact
      end

      private

      def postgres?
        return @postgres unless @postgres.nil?
        @postgres ||= (klass.connection.kind_of?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) rescue false)
      end

      def mysql?
        return @mysql unless @mysql.nil?
        @mysql ||= (klass.connection.kind_of?(ActiveRecord::ConnectionAdapters::Mysql2Adapter) rescue false)
      end

      def ilike
        @ilike ||= (postgres? ? 'ILIKE' : 'LIKE')  # Only Postgres supports ILIKE, Mysql and Sqlite3 use LIKE
      end

    end
  end
end
