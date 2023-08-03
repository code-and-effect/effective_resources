# frozen_string_literal: true

module Effective
  module Resources
    module Paths

      def tenant_path
        Tenant.engine_path(tenant).sub("#{Rails.root}/", '') if tenant?
      end

      # Model
      def model_file
        File.join(*[tenant_path, 'app/models', class_path, "#{name}.rb"].compact)
      end

      # Controller
      def controller_file
        File.join(*[tenant_path, 'app/controllers', class_path, namespace, "#{plural_name}_controller.rb"].compact)
      end

      def admin_effective_controller_file
        File.join(*[tenant_path, 'app/controllers', namespace, "#{plural_name}_controller.rb"].compact)
      end

      # Datatable
      def datatable_file
        File.join(*[tenant_path, 'app/datatables', class_path, namespace, "#{plural_name}_datatable.rb"].compact)
      end

      def effective_datatable_file
        File.join(*[tenant_path, 'app/datatables', namespace, "effective_#{plural_name}_datatable.rb"].compact)
      end

      def admin_effective_datatable_file
        File.join(*[tenant_path, 'app/datatables', namespace, "effective_#{plural_name}_datatable.rb"].compact)
      end

      # Wizards are kinda weird, we need some help for effective_memberships
      def wizard_file_path(resource)
        if resource.class.try(:effective_memberships_applicant?) || resource.class.try(:effective_memberships_applicant_review?)
          File.join(*['effective', plural_name].compact)
        else
          view_file_path(nil)
        end
      end

      # Views
      def view_file(action = :index, partial: false)
        File.join(*[tenant_path, 'app/views', class_path, namespace, plural_name, "#{'_' if partial}#{action}.html.haml"].compact)
      end

      def view_file_path(action = :index)
        File.join(*[class_path, namespace, plural_name, action].compact)
      end

      def admin_effective_view_file(action = :index, partial: false)
        File.join(*[tenant_path, 'app/views', namespace, plural_name, "#{'_' if partial}#{action}.html.haml"].compact)
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
