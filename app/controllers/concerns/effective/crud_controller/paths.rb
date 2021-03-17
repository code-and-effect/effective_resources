module Effective
  module CrudController
    module Paths

      def resource_redirect_path(resource, action)
        submit = commit_action(action)
        redirect = submit[:redirect].respond_to?(:call) ? instance_exec(&submit[:redirect]) : submit[:redirect]

        # If we have a specific redirect for it
        commit_action_redirect = case redirect
          when :index     ; resource_index_path
          when :edit      ; resource_edit_path
          when :show      ; resource_show_path
          when :new       ; resource_new_path
          when :duplicate ; resource_duplicate_path
          when :back      ; referer_redirect_path
          when :save      ; [resource_edit_path, resource_show_path].compact.first
          when Symbol     ; resource_action_path(redirect)
          when String     ; redirect
          else            ; nil
        end

        return commit_action_redirect if commit_action_redirect.present?

        # If we have a magic name
        commit_name_redirect = case params[:commit].to_s
          when 'Save and Add New', 'Add New'
            [resource_new_path, resource_index_path]
          when 'Duplicate'
            [resource_duplicate_path, resource_index_path]
          when 'Continue', 'Save and Continue'
            [resource_index_path]
          else
            []
        end.compact.first

        return commit_name_redirect if commit_name_redirect.present?

        # Otherwise consider the action
        commit_default_redirect = case action
        when :create
          [
            (resource_show_path if EffectiveResources.authorized?(self, :show, resource)),
            (resource_edit_path if EffectiveResources.authorized?(self, :edit, resource)),
            (resource_index_path if EffectiveResources.authorized?(self, :index, resource.class))
          ]
        when :update
          [
            (resource_edit_path if EffectiveResources.authorized?(self, :edit, resource)),
            (resource_show_path if EffectiveResources.authorized?(self, :show, resource)),
            (resource_index_path if EffectiveResources.authorized?(self, :index, resource.class))
          ]
        when :destroy
          [
            referer_redirect_path,
            (resource_index_path if EffectiveResources.authorized?(self, :index, resource.class))
          ]
        else
          [
            referer_redirect_path,
            (resource_edit_path if EffectiveResources.authorized?(self, :edit, resource)),
            (resource_show_path if EffectiveResources.authorized?(self, :show, resource)),
            (resource_index_path if EffectiveResources.authorized?(self, :index, resource.class))
          ]
        end.compact.first

        return commit_default_redirect if commit_default_redirect.present?

        root_path
      end

      def referer_redirect_path
        url = request.referer.to_s

        return if (resource && resource.respond_to?(:destroyed?) && resource.destroyed? && url.include?("/#{resource.to_param}"))
        return if url.include?('duplicate_id=')
        return unless (Rails.application.routes.recognize_path(URI(url).path) rescue false)

        url
      end

      def specific_redirect_path?(action = nil)
        submit = commit_action(action)
        (submit[:redirect].respond_to?(:call) ? instance_exec(&submit[:redirect]) : submit[:redirect]).present?
      end

      def resource_index_path
        effective_resource.action_path(:index)
      end

      def resource_new_path
        effective_resource.action_path(:new)
      end

      def resource_duplicate_path
        effective_resource.action_path(:new, duplicate_id: resource.id)
      end

      def resource_edit_path
        effective_resource.action_path(:edit, resource)
      end

      def resource_show_path
        effective_resource.action_path(:show, resource)
      end

      def resource_destroy_path
        effective_resource.action_path(:destroy, resource)
      end

      def resource_action_path(action)
        effective_resource.action_path(action.to_sym, resource)
      end

    end
  end
end
