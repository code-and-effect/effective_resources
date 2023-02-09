# frozen_string_literal: true

module Effective
  module Resources
    module I18n

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
