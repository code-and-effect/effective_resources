# frozen_string_literal: true

module Effective
  module Resources
    module Tenants

      def tenant?
        defined?(::Tenant)
      end

      def tenant
        return unless tenant?
        return nil unless klass.present?
        return nil unless class_name.include?('::')

        name = class_name.split('::').first.downcase.to_sym
        name if Rails.application.config.tenants[name].present?
      end

    end
  end
end
