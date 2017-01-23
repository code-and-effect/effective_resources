module Effective
  module Resources
    module Paths

      # Controller REST helper paths
      def index_path
        [namespace, plural_name, 'path'].compact * '_'
      end

      def new_path
        ['new', namespace, name, 'path'].compact * '_'
      end

      def show_path
        [namespace, name, 'path'].compact * '_'
      end

      def edit_path
        ['edit', namespace, name, 'path'].compact * '_'
      end

      def action_path(action)
        [action, namespace, name, 'path'].compact * '_'
      end

      # Default file paths
      def model_file
        File.join('app/models', class_path.to_s, "#{name}.rb")
      end

      def controller_file
        File.join('app/controllers', namespace.to_s, "#{plural_name}_controller.rb")
      end

      def datatable_file
        File.join('app/datatables', namespace.to_s, "#{plural_name}_datatable.rb")
      end

    end
  end
end
