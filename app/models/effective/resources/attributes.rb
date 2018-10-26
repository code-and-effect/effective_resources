module Effective
  module Resources
    module Attributes

      # This is the attributes as defined by ActiveRecord table
      # { :name => [:string], ... }
      def attributes
        (klass_attributes.presence || model_attributes.presence)
      end

      def primary_key_attribute
        {klass.primary_key.to_sym => [:integer]}
      end

      # The attributes for each belongs_to
      # { :client_id => [:integer], ... }
      def belong_tos_attributes
        belong_tos.inject({}) do |h, ass|
          unless ass.foreign_key == 'site_id' && ass.respond_to?(:acts_as_site_specific)
            h[ass.foreign_key.to_sym] = [:integer, :index => true]

            if ass.options[:polymorphic]
              h[ass.foreign_type.to_sym] = [:string, :index => true]
            end

          end; h
        end
      end

      def has_manys_attributes
        has_manys_ids.inject({}) { |h, ass| h[ass] = [:array]; h }
      end

      def has_ones_attributes
        has_ones_ids.inject({}) { |h, ass| h[ass] = [:array]; h }
      end

      def effective_addresses_attributes
        return {} unless defined?(EffectiveAddresses) && instance.respond_to?(:effective_address_names)
        instance.effective_address_names.inject({}) { |h, name| h[name] = [:effective_address]; h }
      end

      def effective_assets_attributes
        return {} unless defined?(EffectiveAssets) && instance.respond_to?(:asset_boxes)
        { effective_assets: [:effective_assets] }
      end

      # All will include primary_key, created_at, updated_at and belongs_tos
      # This is the attributes as defined by the effective_resources do .. end block
      # { :name => [:string, { permitted: false }], ... }
      def model_attributes(all: false)
        atts = (model ? model.attributes : {})

        if all # Probably being called by permitted_attributes
          primary_key_attribute
            .merge(belong_tos_attributes)
            .merge(has_manys_attributes)
            .merge(has_ones_attributes)
            .merge(effective_addresses_attributes)
            .merge(effective_assets_attributes)
            .merge(atts)
        else  # This is the migrator. This should match table_attributes
          belong_tos_attributes.merge(atts.reject { |_, v| v[0] == :permitted_param })
        end
      end

      # All table attributes. includes primary_key and belongs_tos
      def table_attributes
        attributes = (klass.new().attributes rescue nil)
        return {} unless attributes

        (attributes.keys - [klass.primary_key]).inject({}) do |h, name|
          if klass.respond_to?(:column_for_attribute) # Rails 4+
            column = klass.column_for_attribute(name)
            h[name.to_sym] = [column.type] if column.table_name # Rails 5 attributes API
          else
            h[name.to_sym] = [klass.columns_hash[name].type]
          end; h
        end
      end

      # Used by effective_crud_controller to generate the permitted params
      def permitted_attributes
        # id = {klass.primary_key.to_sym => [:integer]}
        # bts = belong_tos_ids.inject({}) { |h, ass| h[ass] = [:integer]; h }
        # has_manys = has_manys_ids.inject({}) { |h, ass| h[ass] = [:array]; h }
        # has_manys.each { |k, _| has_manys[k] = model_attributes[k] if model_attributes.key?(k) }
        # Does not include nested, as they are added recursively elsewhere
        # id.merge(bts).merge(model_attributes).merge(has_manys)

        model_attributes(all: true)
      end

      # All attributes from the klass, sorted as per model attributes block.
      # Does not include :id, :created_at, :updated_at unless all is passed
      def klass_attributes(all: false)
        attributes = (klass.new().attributes rescue nil)
        return [] unless attributes

        names = attributes.keys - belong_tos.map { |reference| reference.foreign_key }
        names = names - [klass.primary_key, 'created_at', 'updated_at'] unless all

        attributes = names.inject({}) do |h, name|
          if klass.respond_to?(:column_for_attribute) # Rails 4+
            h[name.to_sym] = [klass.column_for_attribute(name).type]
          else
            h[name.to_sym] = [klass.columns_hash[name].type]
          end; h
        end

        sort_by_model_attributes(attributes)
      end

      private

      def sort_by_model_attributes(attributes)
        return attributes unless model_attributes.present?

        keys = model_attributes.keys

        attributes.sort do |(a, _), (b, _)|
          index = nil

          index ||= if model_attributes.key?(a) && model_attributes.key?(b)
            keys.index(a) <=> keys.index(b)
          elsif model_attributes.key?(a) && !model_attributes.include?(b)
            -1
          elsif !model_attributes.key?(a) && model_attributes.key?(b)
            1
          end

          index || a <=> b
        end.to_h
      end

    end
  end
end




