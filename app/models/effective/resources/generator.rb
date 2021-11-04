# frozen_sting_literals: true

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
        if (prefix = tenant_path_name).present?
          prefix + '/' + controller_path
        else
          controller_path
        end
      end

      def tenant_namespaced_class_name
        if (prefix = tenant_module_name).present?
          prefix + '::' + namespaced_class_name
        else
          namespaced_class_name
        end
      end

      def tenant_namespaced_module_name
        if (prefix = tenant_module_name).present?
          prefix + '::' + namespaced_module_name
        else
          namespaced_module_name
        end
      end

      def tenant_class_name
        if (prefix = tenant_module_name).present?
          prefix + '::' + class_name
        else
          class_name
        end
      end

    end
  end
end
