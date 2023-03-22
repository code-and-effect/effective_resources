# frozen_string_literal: true

module Effective
  module Resources
    module I18n

      def human_action_name(action)
        if klass.respond_to?(:model_name)
          value = ::I18n.t("activerecord.actions.#{klass.model_name.i18n_key}.#{action}")
          return value unless value.start_with?('translation missing:')
        end

        if(crud_actions.include?(action))
          # Raises exception if not present
          return EffectiveResources.et("effective_resources.actions.#{action}")
        end

        action.to_s.titleize
      end

      def human_action_confirm(action)
        if klass.respond_to?(:model_name)
          value = ::I18n.t("activerecord.actions.#{klass.model_name.i18n_key}.#{action}_confirm")
          return value unless value.start_with?('translation missing:')
        end

        "Really #{human_action_name(action)} @resource?"
      end

      def human_name
        if klass.respond_to?(:model_name)
          klass.model_name.human
        else
          name.gsub('::', ' ').underscore.gsub('_', ' ')
        end
      end

      def human_plural_name
        if klass.respond_to?(:model_name)
          klass.model_name.human.pluralize
        else
          name.pluralize.gsub('::', ' ').underscore.gsub('_', ' ')
        end
      end

    end
  end
end
