module Effective
  module Resources
    module Paths

      #
      # TODO: Delete these. Once effective_developer is updated
      #
      # # Controller REST helper paths
      # def index_path(check: false)
      #   path = [namespace, plural_name, 'path'].compact * '_'
      #   path if (!check || path_exists?(path))
      # end

      # def new_path(check: false)
      #   path = ['new', namespace, name, 'path'].compact * '_'
      #   path if (!check || path_exists?(path))
      # end

      # def show_path(check: false)
      #   path = [namespace, name, 'path'].compact * '_'
      #   path if (!check || path_exists?(path, 1))
      # end

      # def destroy_path(check: false)
      #   path = [namespace, name, 'path'].compact * '_'
      #   path if (!check || path_exists?(path, 1, :delete))
      # end

      # def edit_path(check: false)
      #   path = ['edit', namespace, name, 'path'].compact * '_'
      #   path if (!check || path_exists?(path, 1))
      # end

      # def action_path(action, check: false)
      #   path = [action, namespace, name, 'path'].compact * '_'
      #   path if (!check || path_exists?(path, 1, :any))
      # end

      # def action_post_path(action, check: false)
      #   path = [action, namespace, name, 'path'].compact * '_'
      #   path if (!check || path_exists?(path, 1, :post) || path_exists?(path, 1, :put) || path_exists?(path, 1, :patch))
      # end

      # def path_exists?(path, param = nil, verb = :get)
      #   routes = Rails.application.routes

      #   return false unless routes.url_helpers.respond_to?(path)
      #   (routes.recognize_path(routes.url_helpers.send(path, param), method: verb).present? rescue false)
      # end

      # # _helper methods also put in the (@thing)
      # alias_method :index_path_helper, :index_path
      # alias_method :new_path_helper, :new_path

      # def show_path_helper(at: true)
      #   show_path + '(' + (at ? '@' : '') + name + ')'
      # end

      # def edit_path_helper(at: true)
      #   edit_path + '(' + (at ? '@' : '') + name + ')'
      # end

      # def action_path_helper(action, at: true)
      #   action_path(action) + '(' + (at ? '@' : '') + name + ')'
      # end

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
