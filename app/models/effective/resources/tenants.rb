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

      def tenant_engines_blacklist
        return [] unless tenant?
        Rails.application.config.tenants.map { |name, _| name.to_s.classify }
      end
    end
  end
end
