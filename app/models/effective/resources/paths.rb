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

      # _helper methods also put in the (@thing)
      alias_method :index_path_helper, :index_path
      alias_method :new_path_helper, :new_path

      def show_path_helper(at: true)
        show_path + '(' + (at ? '@' : '') + name + ')'
      end

      def edit_path_helper(at: true)
        edit_path + '(' + (at ? '@' : '') + name + ')'
      end

      def action_path_helper(action, at: true)
        action_path(action) + '(' + (at ? '@' : '') + name + ')'
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

      def view_file(action = :index, partial: false)
        File.join('app/views', namespace.to_s, (namespace.present? ? '' : class_path), plural_name, "#{'_' if partial}#{action}.html.haml")
      end

    end
  end
end
