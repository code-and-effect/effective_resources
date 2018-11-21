module Effective
  module CrudController
    module Respond
      def respond_with_success(format, resource, action)
        if specific_redirect_path?(action)
          format.html do
            flash[:success] ||= resource_flash(:success, resource, action)
            redirect_to(resource_redirect_path(action))
          end

          format.js do
            flash[:success] ||= resource_flash(:success, resource, action)
            redirect_to(resource_redirect_path(action))
          end
        elsif lookup_context.template_exists?(action, _prefixes)
          format.html do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            # action.html.haml
          end

          format.js do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            reload_resource
            # action.js.erb
          end
        else # Default
          format.html do
            flash[:success] ||= resource_flash(:success, resource, action)
            redirect_to(resource_redirect_path(action))
          end

          format.js do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            render(:member_action, locals: { action: action })
          end
        end
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
        when 'destroy'
          # We always need to redirect here
          flash[:danger] = flash.now.delete(:danger)

          format.html { redirect_to(resource_redirect_path(action)) }
          format.js { redirect_to(resource_redirect_path(action)) }
        else # member_action
          format.html do
            if lookup_context.template_exists?(action, _prefixes)
              @page_title ||= "#{action.to_s.titleize} #{resource}"
              render(action, locals: { action: action })
            elsif resource_edit_path && (referer_redirect_path || '').end_with?(resource_edit_path)
              @page_title ||= "Edit #{resource}"
              render :edit
            elsif resource_new_path && (referer_redirect_path || '').end_with?(resource_new_path)
              @page_title ||= "New #{resource_name.titleize}"
              render :new
            elsif resource_show_path && (referer_redirect_path || '').end_with?(resource_show_path)
              @page_title ||= resource_name.titleize
              render :show
            else
              @page_title ||= resource.to_s
              flash[:danger] = flash.now.delete(:danger)
              redirect_to(referer_redirect_path || resource_redirect_path(action))
            end
          end
        end

        format.js do
          view = lookup_context.template_exists?(action, _prefixes) ? action : :member_action
          render(view, locals: { action: action })
        end
      end

      # For destroy.js
      def respond_with_error_and_redirect(format, resource, action)
        flash.delete(:success)
        flash[:danger] ||= resource_flash(:danger, resource, action)

        format.html do
          redirect_to(resource_redirect_path(action))
        end

        format.js do
          redirect_to(resource_redirect_path(action))
        end
      end

    end
  end
end
