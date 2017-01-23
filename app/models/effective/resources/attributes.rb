module Effective
  module Resources
    module Attributes

      def attributes
        klass_attributes.presence || written_attributes.presence
      end

      # All attributes from the klass, sorted as per attributes block.
      # Does not include :id, :created_at, :updated_at
      def klass_attributes
        return [] unless (klass rescue false)  # This class doesn't exist

        begin
          attributes = klass.new().attributes
        rescue ActiveRecord::StatementInvalid => e
          pending = ActiveRecord::Migrator.new(:up, ActiveRecord::Migrator.migrations(ActiveRecord::Migrator.migrations_paths)).pending_migrations.present?

          if e.message.include?('PG::UndefinedTable') && pending
            migrate = ask("Unable to read the attributes of #{class_name}. There are pending migrations. Run db:migrate now? [y/n]")
            system('bundle exec rake db:migrate') if migrate.to_s.include?('y')
          end
        end

        begin
          attributes = klass.new().attributes
        rescue => e
          return []
        end

        attributes = (attributes.keys - [klass.primary_key, 'created_at', 'updated_at']).map do |att|
          if klass.respond_to?(:column_for_attribute) # Rails 4+
            Effective::Attribute.new(att, klass.column_for_attribute(att).try(:type))
          else
            Effective::Attribute.new(att, klass.columns_hash[att].try(:type))
          end
        end

        sort(attributes)
      end

      def written_attributes
        _initialize_written if @written_attributes.nil?
        @written_attributes
      end

      private

      def sort(attributes)
        attributes.sort do |a, b|
          index = nil

          index ||= if written_attributes.include?(a) && written_attributes.include?(b)
            written_attributes.index(a) <=> written_attributes.index(b)
          elsif written_attributes.include?(a) && !written_attributes.include?(b)
            -1
          elsif !written_attributes.include?(a) && written_attributes.include?(b)
            1
          end

          index || a <=> b
        end
      end

    end
  end
end




