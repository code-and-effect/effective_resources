# frozen_string_literal: true

module Effective
  module Resources
    module Generator

      def module_name
        return nil unless class_name.split('::').length > 1
        class_name.split('::').first
      end

      # Acpa
      def module_namespace
        return nil unless namespaces.present?
        Array(namespaces + [nil]).map { |name| name.to_s.classify } * '::'
      end

      # Admin::Courses
      def module_namespaced
        (Array(namespaces).map { |name| name.to_s.classify } + [plural_name.classify.pluralize]) * '::'
      end

      def namespaced_class_name # 'Admin::Effective::Post'
        (Array(namespaces).map { |name| name.to_s.classify } + [class_name]) * '::'
      end

      def namespaced_module_name # 'Admin::EffectivePosts'
        Array(namespaces).map { |name| name.to_s.classify }.join('::') + '::' + class_name.gsub('::', '')
      end

      # Tenants
      def tenant_controller_path
        (Tenant.module_name.downcase + '/' + controller_path) if tenant?
      end

      def tenant_namespaced_class_name
        (Tenant.module_name + '::' + namespaced_class_name) if tenant?
      end

      def tenant_namespaced_module_name
        (Tenant.module_name + '::' + namespaced_module_name) if tenant?
      end

      def tenant_class_name
        (Tenant.module_name + '::' + class_name) if tenant?
      end

    end
  end
end
