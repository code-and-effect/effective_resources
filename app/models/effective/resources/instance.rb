# frozen_string_literal: true

module Effective
  module Resources
    module Instance
      attr_accessor :instance

      # This is written for use by effective_logging and effective_trash
      BLACKLIST = [:logged_changes, :trash]

      def instance
        @instance || (klass.new if klass)
      end

      # called by effective_trash and effective_logging
      def instance_attributes(only: nil, except: nil, associations: true)
        return {} unless instance.present?

        # Build up our only and except
        only = Array(only).map(&:to_sym)
        except = Array(except).map(&:to_sym) + BLACKLIST

        # Simple Attributes
        attributes = { attributes: instance.attributes.symbolize_keys }

        attributes[:attributes] = attributes[:attributes].except(*except) if except.present?
        attributes[:attributes] = attributes[:attributes].slice(*only) if only.present?

        # Collect to_s representations of all belongs_to associations
        belong_tos.each do |association|
          next if except.present? && except.include?(association.name)
          next unless only.blank? || only.include?(association.name)

          attributes[association.name] = instance.send(association.name).to_s
        end

        if associations 
          # Grab the instance attributes of each nested resource
          nested_resources.each do |association|
            next if except.present? && except.include?(association.name)
            next unless only.blank? || only.include?(association.name)

            next if association.options[:through]

            attributes[association.name] ||= {}

            Array(instance.send(association.name)).each_with_index do |child, index|
              next unless child.present?

              resource = Effective::Resource.new(child)
              attributes[association.name][index] = resource.instance_attributes(only: only, except: except)
            end
          end

          (action_texts + has_ones).each do |association|
            next if except.present? && except.include?(association.name)
            next unless only.blank? || only.include?(association.name)

            attributes[association.name] = instance.send(association.name).to_s
          end

          has_manys.each do |association|
            next if except.present? && except.include?(association.name)
            next unless only.blank? || only.include?(association.name)

            next if BLACKLIST.include?(association.name)
            attributes[association.name] = instance.send(association.name).map { |obj| obj.to_s }
          end

          has_and_belongs_to_manys.each do |association|
            next if except.present? && except.include?(association.name)
            next unless only.blank? || only.include?(association.name)

            attributes[association.name] = instance.send(association.name).map { |obj| obj.to_s }
          end
        end

        attributes.delete_if { |_, value| value.blank? }
      end

      def instance_action_texts_previous_changes
        return {} unless instance.present? && action_texts.present?

        action_texts
          .map { |ass| instance.send(ass.name) }
          .compact
          .flatten
          .select { |obj| obj.previous_changes['body'].present? }
          .inject({}) { |h, obj| h[obj.name.to_sym] = obj.previous_changes['body']; h }
      end

      # used by effective_logging
      def instance_changes(only: nil, except: nil)
        return {} unless instance.present?

        action_texts_changes = instance_action_texts_previous_changes()
        return {} unless instance.previous_changes.present? || action_texts_changes.present?

        # Build up our only and except
        only = Array(only).map(&:to_sym)
        except = Array(except).map(&:to_sym) + BLACKLIST

        changes = instance.previous_changes.symbolize_keys.delete_if do |attribute, (before, after)|
          begin
            (before.kind_of?(ActiveSupport::TimeWithZone) && after.kind_of?(ActiveSupport::TimeWithZone) && before.to_i == after.to_i) ||
            (before.kind_of?(Hash) && after.kind_of?(Hash) && before == after) ||
            (before == nil && after == false) || (before == nil && after == ''.freeze)
          rescue => e
            true
          end
        end

        changes = changes.except(*except) if except.present?
        changes = changes.slice(*only) if only.present?

        action_texts_changes.each do |name, (before, after)|
          next if except.present? && except.include?(name)
          next unless only.blank? || only.include?(name)

          changes[name] = [before.to_s, after.to_s]
        end

        # Log to_s changes on all belongs_to associations
        belong_tos.each do |association|
          next if except.present? && except.include?(association.name)
          next unless only.blank? || only.include?(association.name)

          if (change = changes.delete(association.foreign_key)).present?
            changes[association.name] = [(association.klass.find_by_id(change.first) if changes.first), instance.send(association.name)]
          end
        end

        changes
      end

    end
  end
end
