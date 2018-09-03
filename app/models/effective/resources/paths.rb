module Effective
  module Resources
    module Paths

      def model_file
        File.join('app/models', class_path.to_s, "#{name}.rb")
      end

      def controller_file
        File.join('app/controllers', namespace.to_s, "#{plural_name}_controller.rb")
      end

      def datatable_file
        File.join('app/datatables', namespace.to_s, "#{plural_name}_datatable.rb")
      end

      def view_file(action = :index, partial: false)
        File.join('app/views', namespace.to_s, (namespace.present? ? '' : class_path), plural_name, "#{'_' if partial}#{action}.html.haml")
      end

      def flat_view_file(action = :index, partial: false)
        File.join('app/views', plural_name, "#{'_' if partial}#{action}.html.haml")
      end

    end
  end
end
