module Effective
  module Resources
    module Klass

      def klass
        @model_klass
      end

      def datatable_klass
        if defined?(EffectiveDatatables)
          "#{controller_path.classify.pluralize}Datatable".safe_constantize ||
          "#{controller_path.classify}Datatable".safe_constantize ||
          "#{namespaced_class_name.pluralize}Datatable".safe_constantize ||
          "#{namespaced_module_name.pluralize}Datatable".safe_constantize ||
          "#{namespaced_class_name.pluralize.gsub('::', '')}Datatable".safe_constantize ||
          "#{class_name.pluralize.camelize}Datatable".safe_constantize ||
          "#{class_name.pluralize.camelize.gsub('::', '')}Datatable".safe_constantize ||
          "#{name.pluralize.camelize}Datatable".safe_constantize ||
          "#{name.pluralize.camelize.gsub('::', '')}Datatable".safe_constantize ||
          "Effective::Datatables::#{namespaced_class_name.pluralize}".safe_constantize ||
          "Effective::Datatables::#{class_name.pluralize.camelize}".safe_constantize ||
          "Effective::Datatables::#{name.pluralize.camelize}".safe_constantize
        end
      end

      def controller_klass
        "#{namespaced_class_name.pluralize}Controller".safe_constantize ||
        "#{class_name.pluralize.classify}Controller".safe_constantize ||
        "#{name.pluralize.classify}Controller".safe_constantize ||
        "#{initialized_name.to_s.classify.pluralize}Controller".safe_constantize ||
        "#{initialized_name.to_s.classify}Controller".safe_constantize
      end

      def active_record?
        klass && klass.ancestors.include?(ActiveRecord::Base)
      end

      def active_model?
        klass && klass.ancestors.include?(ActiveModel::Model)
      end

    end
  end
end
