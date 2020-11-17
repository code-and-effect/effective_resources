module Effective
  module CrudController
    module Respond
      def respond_with_success(resource, action)
        return if (response.body.respond_to?(:length) && response.body.length > 0)

        if specific_redirect_path?(action)
          respond_to do |format|
            format.html do
              flash[:success] ||= resource_flash(:success, resource, action)
              redirect_to(resource_redirect_path(action))
            end

            format.js do
              flash[:success] ||= resource_flash(:success, resource, action)
              redirect_to(resource_redirect_path(action))
            end
          end
        elsif template_present?(action)
          respond_to do |format|
            format.html do
              flash.now[:success] ||= resource_flash(:success, resource, action)
              render(action) # action.html.haml
            end

            format.js do
              flash.now[:success] ||= resource_flash(:success, resource, action)
              #reload_resource unless action == :destroy # Removed.
              render(action) # action.js.erb
            end
          end
        else # Default
          respond_to do |format|
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
      end

      def respond_with_error(resource, action)
        return if response.body.present?

        flash.delete(:success)
        flash.now[:danger] ||= resource_flash(:danger, resource, action)

        respond_to do |format|
          case action_name.to_sym
          when :create
            format.html { render :new }
          when :update
            format.html { render :edit }
          when :destroy
            format.html do
              redirect_flash
              redirect_to(resource_redirect_path(action))
            end
          else
            if template_present?(action)
              format.html { render(action, locals: { action: action }) }
            elsif request.referer.to_s.end_with?('/edit')
              format.html { render :edit }
            elsif request.referer.to_s.end_with?('/new')
              format.html { render :new }
            else
              format.html do
                redirect_flash
                redirect_to(resource_redirect_path(action))
              end
            end
          end

          format.js do
            view = template_present?(action) ? action : :member_action
            render(view, locals: { action: action }) # action.js.erb
          end
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
