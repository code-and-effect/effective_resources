module Effective
  module Resources
    module Sql

      def column(name)
        name = name.to_s
        columns.find { |col| col.name == name || (belongs_to(name) && col.name == belongs_to(name).foreign_key) }
      end

      def columns
        klass.respond_to?(:columns) ? klass.columns : []
      end

      def column_names
        @column_names ||= columns.map { |col| col.name }
      end

      def table
        klass.unscoped.table
      end

      def max_id
        return 999999 unless klass.respond_to?(:unscoped)
        @max_id ||= klass.unscoped.maximum(klass.primary_key).to_i
      end

      def sql_column(name)
        column = column(name)
        return nil unless table && column

        [klass.connection.quote_table_name(table.name), klass.connection.quote_column_name(column.name)].join('.')
      end

      def sql_direction(name)
        name.to_s.downcase == 'desc' ? 'DESC'.freeze : 'ASC'.freeze
      end

      # This is for EffectiveDatatables (col as:)
      # Might be :name, or 'users.name'
      def sql_type(name)
        name = name.to_s.split('.').first

        return :belongs_to if belongs_to(name)

        column = column(name)

        if column.present?
          column.type
        elsif has_many(name)
          :has_many
        elsif has_one(name)
          :has_one
        elsif belongs_to_polymorphic(name)
          :belongs_to_polymorphic
        elsif has_and_belongs_to_many(name)
          :has_and_belongs_to_many
        elsif active_storage(name)
          :active_storage
        elsif name == 'id' && defined?(EffectiveObfuscation) && klass.respond_to?(:deobfuscate)
          :effective_obfuscation
        elsif name == 'roles' && defined?(EffectiveRoles) && klass.respond_to?(:with_role)
          :effective_roles
        elsif (name.include?('_address') || name.include?('_addresses')) && defined?(EffectiveAddresses) && (klass.new rescue nil).respond_to?(:effective_addresses)
          :effective_addresses
        elsif name.ends_with?('_id')
          :integer
        else
          :string
        end
      end

      # This tries to figure out the column we should order this collection by.
      # Whatever would match up with the .to_s
      # Unless it's set from outside by datatables...
      def sort_column
        return @_sort_column if @_sort_column

        ['name', 'title', 'label', 'subject', 'full_name', 'first_name', 'email', 'number', 'description'].each do |name|
          return name if column_names.include?(name)
        end

        klass.primary_key
      end

      def sort_column=(name)
        raise "unknown sort column: #{name}" unless column_names.include?(name)
        @_sort_column = name
      end

      # Any string or text columns
      # TODO: filter out _type columns for polymorphic
      def search_columns
        return @_search_columns if @_search_columns
        columns.map { |column| column.name if [:string, :text].include?(column.type) }.compact
      end

      def search_columns=(name)
        names = Array(name)
        names.each { |name| raise "unknown search column: #{name}" unless column_names.include?(name) }
        @_search_columns = names
      end

      def ilike
        @ilike ||= (postgres? ? 'ILIKE' : 'LIKE')  # Only Postgres supports ILIKE, Mysql and Sqlite3 use LIKE
      end

      def postgres?
        return @postgres unless @postgres.nil?
        @postgres ||= (klass.connection.kind_of?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) rescue false)
      end

      def mysql?
        return @mysql unless @mysql.nil?
        @mysql ||= (klass.connection.kind_of?(ActiveRecord::ConnectionAdapters::Mysql2Adapter) rescue false)
      end

      def is_null(sql_column)
        mysql? == true ? "ISNULL(#{sql_column})" : "#{sql_column} IS NULL"
      end

    end
  end
end
