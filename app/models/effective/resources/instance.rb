module Effective
  module Resources
    module Instance
      attr_reader :instance

      # This is written for use by effective_logging and effective_trash

      def instance
        @instance || klass.new
      end

      def instance_attributes
        return {} unless instance.present?

        attributes = { attributes: instance.attributes }

        # Collect to_s representations of all belongs_to associations
        belong_tos.each do |association|
          attributes[association.name] = instance.send(association.name).to_s
        end

        nested_resources.each do |association|
          attributes[association.name] ||= {}

          Array(instance.send(association.name)).each_with_index do |child, index|
            resource = Effective::Resource.new(child)
            attributes[association.name][index] = resource.instance_attributes
          end
        end

        has_ones.each do |association|
          attributes[association.name] = instance.send(association.name).to_s
        end

        has_manys.each do |association|
          attributes[association.name] = instance.send(association.name).map { |obj| obj.to_s }
        end

        has_and_belongs_to_manys.each do |association|
          attributes[association.name] = instance.send(association.name).map { |obj| obj.to_s }
        end

        attributes.delete_if { |_, value| value.blank? }
      end

      def instance_changes
        return {} unless (instance.present? && instance.changes.present?)

        changes = instance.changes.delete_if do |attribute, (before, after)|
          begin
            (before.kind_of?(ActiveSupport::TimeWithZone) && after.kind_of?(ActiveSupport::TimeWithZone) && before.to_i == after.to_i) ||
            (before == nil && after == false) || (before == nil && after == ''.freeze)
          rescue => e
            true
          end
        end

        # Log to_s changes on all belongs_to associations
        belong_tos.each do |association|
          if (change = changes.delete(association.foreign_key)).present?
            changes[association.name] = [(association.klass.find_by_id(change.first) if changes.first), instance.send(association.name)]
          end
        end

        changes
      end

    end
  end
end




