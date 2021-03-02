# frozen_string_literal: true

module Effective
  module Resources
    module Paths

      def tenant_path
        return unless tenant.present?
        Tenant.engine_path(tenant).sub("#{Rails.root}/", '')
      end

      def model_file
        File.join(*[tenant_path, 'app/models', class_path, "#{name}.rb"].compact)
      end

      def controller_file
        File.join(*[tenant_path, 'app/controllers', class_path, namespace, "#{plural_name}_controller.rb"].compact)
      end

      def datatable_file
        File.join(*[tenant_path, 'app/datatables', class_path, namespace, "#{plural_name}_datatable.rb"].compact)
      end

      def view_file(action = :index, partial: false)
        File.join(*[tenant_path, 'app/views', class_path, namespace, plural_name, "#{'_' if partial}#{action}.html.haml"].compact)
      end

      def view_file_path(action = :index)
        File.join(*[class_path, namespace, plural_name, action].compact)
      end

      def flat_view_file(action = :index, partial: false)
        File.join(*[tenant_path, 'app/views', class_path, plural_name, "#{'_' if partial}#{action}.html.haml"].compact)
      end

      def routes_file
        File.join(*[tenant_path, 'config/routes.rb'].compact)
      end

      def abilities_file
        File.join(*[tenant_path, 'app/models/', class_path, 'ability.rb'].compact)
      end

      def menu_file
        File.join(*[tenant_path, 'app/views/layouts', class_path, '_navbar.html.haml'].compact)
      end

      def admin_menu_file
        File.join(*[tenant_path, 'app/views/layouts', class_path, '_navbar_admin.html.haml'].compact)
      end

      # Used by render_resource_partial and render_resource_form to guess the view path
      def view_paths
        mod = class_name.split('::').first.downcase

        [
          [mod, *namespace, plural_name].join('/'),
          [mod, *namespace, name].join('/'),
          [*namespace, mod, plural_name].join('/'),
          [*namespace, mod, name].join('/'),
          [mod, plural_name].join('/'),
          [mod, name].join('/'),
          [*namespace, plural_name].join('/'),
          [*namespace, name].join('/')
        ]
      end

    end
  end
end
