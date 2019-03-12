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
        elsif template_present?(action)
          format.html do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            render(action) # action.html.haml
          end

          format.js do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            #reload_resource unless action == :destroy # Removed.
            render(action) # action.js.erb
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

        redirect_flash if specific_redirect_path?(:error)

        run_callbacks(:resource_render)

        if specific_redirect_path?(:error)
          format.html { redirect_to resource_redirect_path(:error) }
          format.js { redirect_to resource_redirect_path(:error) }
          return
        end

        # HTML responder
        case action.to_sym
        when :create
          format.html { render :new }
        when :update
          format.html { render :edit }
        when :destroy
          format.html do
            redirect_flash
            redirect_to(resource_redirect_path(action))
          end
        else # member action
          format.html do
            if resource_edit_path && referer_redirect_path.to_s.end_with?(resource_edit_path)
              @page_title ||= "Edit #{resource}"
              render :edit
            elsif resource_new_path && referer_redirect_path.to_s.end_with?(resource_new_path)
              @page_title ||= "New #{resource_name.titleize}"
              render :new
            elsif resource_action_path(action) && referer_redirect_path.to_s.end_with?(resource_action_path(action)) && template_present?(action)
              @page_title ||= "#{action.to_s.titleize} #{resource}"
              render(action, locals: { action: action })
            elsif resource_show_path && referer_redirect_path.to_s.end_with?(resource_show_path)
              @page_title ||= resource_name.titleize
              render :show
            else
              @page_title ||= resource.to_s
              redirect_flash
              redirect_to(referer_redirect_path || resource_redirect_path(action))
            end
          end
        end

        format.js do
          view = template_present?(action) ? action : :member_action
          render(view, locals: { action: action }) # action.js.erb
        end
      end

      private

      def redirect_flash
        return unless flash.now[:danger].present?

        danger = flash.now[:danger]
        flash.now[:danger] = nil
        flash[:danger] ||= danger
      end

      def template_present?(action)
        lookup_context.template_exists?("#{action}.#{request.format.symbol.to_s.sub('json', 'js').presence || 'html'}", _prefixes)
      end

    end
  end
end
