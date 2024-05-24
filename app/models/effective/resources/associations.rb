# frozen_string_literal: true

module Effective
  module Resources
    module Associations
      INVALID_SCOPE_NAMES = ['delete_all', 'destroy_all', 'update_all', 'update_counters', 'load', 'reload', 'reset', 'to_a', 'to_sql', 'explain', 'inspect']

      def macros
        [:belongs_to, :belongs_to_polymorphic, :has_many, :has_and_belongs_to_many, :has_one]
      end

      def belong_tos
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        klass.reflect_on_all_associations(:belongs_to)
      end

      # author_id, post_id
      def belong_tos_ids
        belong_tos.map { |ass| (ass.options[:foreign_key] || "#{ass.name}_id").to_sym }
      end

      def has_anys
        (has_ones + has_manys + has_and_belongs_to_manys)
      end

      def has_manys_ids
        (has_manys + has_and_belongs_to_manys).map { |ass| "#{ass.plural_name.singularize}_ids".to_sym }
      end

      def has_ones
        return [] unless klass.respond_to?(:reflect_on_all_associations)

        blacklist = ['ActiveStorage::', 'ActionText::']

        klass.reflect_on_all_associations(:has_one).reject { |ass| blacklist.any? { |val| ass.class_name.start_with?(val) } }
      end

      def has_ones_ids
        has_ones.map { |ass| "#{ass.name}_id".to_sym }
      end

      def has_manys
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        klass.reflect_on_all_associations(:has_many).reject { |ass| ass.options[:autosave] || ass.class_name.to_s.start_with?('ActiveStorage::') }
      end

      def has_and_belongs_to_manys
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        klass.reflect_on_all_associations(:has_and_belongs_to_many)
      end

      def active_storages
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        klass.reflect_on_all_associations.select { |ass| ass.class_name == 'ActiveStorage::Attachment' }
      end

      def active_storage_has_manys
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        klass.reflect_on_all_associations(:has_many).select { |ass| ass.class_name == 'ActiveStorage::Attachment' }
      end

      def active_storage_has_manys_ids
        active_storage_has_manys.map { |ass| ass.name.to_s.gsub(/_attachments\z/, '').to_sym }
      end

      def active_storage_has_ones
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        klass.reflect_on_all_associations(:has_one).select { |ass| ass.class_name == 'ActiveStorage::Attachment' }
      end

      def active_storage_has_ones_ids
        active_storage_has_ones.map { |ass| ass.name.to_s.gsub(/_attachment\z/, '').to_sym }
      end

      def action_texts
        klass.reflect_on_all_associations(:has_one).select { |ass| ass.class_name == 'ActionText::RichText' } +
        klass.reflect_on_all_associations(:has_many).select { |ass| ass.class_name == 'ActionText::RichText' }
      end

      def action_texts_has_ones_ids
        action_texts.map { |ass| ass.name.to_s.gsub(/\Arich_text_/, '').to_sym }
      end

      def nested_resources
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        klass.reflect_on_all_associations(:has_many).select { |ass| ass.options[:autosave] } +
        klass.reflect_on_all_associations(:has_one).select { |ass| ass.options[:autosave] }
      end

      def accepts_nested_attributes
        return [] unless klass.respond_to?(:reflect_on_all_associations)
        klass.reflect_on_all_associations.select { |ass| ass.options[:autosave] }
      end

      def associated(name)
        name = (name.to_s.end_with?('_id') ? name.to_s[0...-3] : name).to_sym
        klass.reflect_on_all_associations.find { |ass| ass.name == name } || effective_addresses(name)
      end

      def belongs_to(name)
        if name.kind_of?(String) || name.kind_of?(Symbol)
          name = (name.to_s.end_with?('_id') ? name.to_s[0...-3] : name).to_sym
          belong_tos.find { |ass| !ass.options[:polymorphic] && ass.name == name }
        else
          belong_tos.find { |ass| !ass.options[:polymorphic] && ass.klass == name.class }
        end
      end

      def belongs_to_polymorphic(name)
        name = (name.to_s.end_with?('_id') ? name.to_s[0...-3] : name).to_sym
        belong_tos.find { |ass| ass.options[:polymorphic] && ass.name == name }
      end

      def has_and_belongs_to_many(name)
        name = name.to_sym
        has_and_belongs_to_manys.find { |ass| ass.name == name }
      end

      def has_many(name)
        name = name.to_sym
        (has_manys + nested_resources).find { |ass| ass.name == name }
      end

      def has_one(name)
        name = name.to_sym
        has_ones.find { |ass| ass.name == name }
      end

      def effective_addresses(name)
        return unless defined?(EffectiveAddresses) && has_many(:addresses).try(:klass) == Effective::Address

        name = name.to_s.downcase
        return unless name.end_with?('_address') || name.end_with?('_addresses')

        category = name.split('_').reject { |name| name == 'address' || name == 'addresses' }.join('_')
        return unless category.present?

        Effective::Address.where(category: category).where(addressable_type: class_name)
      end

      def active_storage(name)
        name = name.to_sym
        active_storages.find { |ass| ass.name.to_s.gsub(/_attachment(s?)\z/, '').to_sym == name }
      end

      def nested_resource(name)
        name = name.to_sym
        nested_resources.find { |ass| ass.name == name }
      end

      def scope?(name)
        return false unless name.present?

        name = name.to_s
        return false unless klass.respond_to?(name)

        return false if INVALID_SCOPE_NAMES.include?(name)
        return false if name.include?('?') || name.include?('!') || name.include?('=')

        is_scope = false

        EffectiveResources.transaction(klass) do
          begin
            is_scope = klass.public_send(name).kind_of?(ActiveRecord::Relation)
          rescue => e
          end

          raise ActiveRecord::Rollback unless is_scope
        end

        is_scope
      end

    end
  end
end
