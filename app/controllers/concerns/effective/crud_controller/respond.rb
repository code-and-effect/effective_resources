# frozen_string_literal: true

module Effective
  module CrudController
    module Respond
      def respond_with_success(resource, action)
        return if (response.body.respond_to?(:length) && response.body.length > 0)

        if specific_redirect_path?(action)
          respond_to do |format|
            format.html do
              flash[:success] ||= resource_flash(:success, resource, action)
              redirect_to(resource_redirect_path(resource, action))
            end

            format.js do
              flash[:success] ||= resource_flash(:success, resource, action)

              if params[:_datatable_action]
                redirect_to(resource_redirect_path(resource, action))
              else
                render(
                  (template_present?(action) ? action : :member_action),
                  locals: { action: action, remote_form_redirect: resource_redirect_path(resource, action)}
                )
              end

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
              render(action) # action.js.erb
            end
          end
        else # Default
          respond_to do |format|
            format.html do
              flash[:success] ||= resource_flash(:success, resource, action)
              redirect_to(resource_redirect_path(resource, action))
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

        if specific_redirect_error_path?(action)
          respond_to do |format| 
            format.html do
              redirect_flash
              redirect_to(resource_redirect_error_path(resource, action))
            end

            format.js do
              view = template_present?(action) ? action : :member_action
              render(view, locals: { action: action }) # action.js.erb
            end
          end
        else
          respond_to do |format| # Default
            case action_name.to_sym
            when :create
              format.html { render :new }
            when :update
              format.html { render :edit }
            when :destroy
              format.html do
                redirect_flash
                redirect_to(resource_redirect_path(resource, action))
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
                  redirect_to(resource_redirect_path(resource, action))
                end
              end
            end

            format.js do
              view = template_present?(action) ? action : :member_action
              render(view, locals: { action: action }) # action.js.erb
            end
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

      def template_present?(action, format: nil)
        format = Array(format).presence
        formats = [(request.format.symbol.to_s.sub('json', 'js').presence || 'html').to_sym]
        lookup_context.template_exists?(action, _prefixes, formats: (format || formats))
      end

    end
  end
end
