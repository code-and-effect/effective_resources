module Effective
  module Resources
    module Klass

      def klass
        namespaced_class_name.safe_constantize || class_name.safe_constantize || name.safe_constantize
      end

      def datatable_klass
        @datatable_klass ||= if defined?(EffectiveDatatables)
          "#{namespaced_class_name.pluralize}Datatable".safe_constantize ||
          "#{class_name.pluralize.camelize}Datatable".safe_constantize ||
          "#{name.pluralize.camelize}Datatable".safe_constantize ||
          "Effective::Datatables::#{namespaced_class_name.pluralize}".safe_constantize ||
          "Effective::Datatables::#{class_name.pluralize.camelize}".safe_constantize ||
          "Effective::Datatables::#{name.pluralize.camelize}".safe_constantize
        end
      end

    end
  end
end
