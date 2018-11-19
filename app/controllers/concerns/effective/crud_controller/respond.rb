module Effective
  module CrudController
    module Respond
      def respond_with_success(format, resource, action)
        if specific_redirect_path?
          format.html do
            flash[:success] ||= resource_flash(:success, resource, action)
            redirect_to(resource_redirect_path(action))
          end

          format.js do
            flash[:success] ||= resource_flash(:success, resource, action)
            redirect_to(resource_redirect_path(action))
          end

          return true
        end

        # Render template if it exists
        if lookup_context.template_exists?(action, _prefixes)
          format.html do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            # action.html.haml
          end

          format.js do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            reload_resource
            # action.js.erb
          end

          return false
        end

        # Default
        format.html do
          flash[:success] ||= resource_flash(:success, resource, action)
          redirect_to(resource_redirect_path(action))
        end

        format.js do
          flash[:success] ||= resource_flash(:success, resource, action)
          redirect_to(resource_redirect_path(action))
        end

        true
      end

      def respond_with_error(format, resource, action)
        flash.delete(:success)
        flash.now[:danger] ||= resource_flash(:danger, resource, action)

        run_callbacks(:resource_render)

        case params[:action]
        when 'create'
          format.html { render :new }
        when 'update'
          format.html { render :edit }
        else
          format.html { render action }
        end

        format.js {}
      end

    end
  end
end
