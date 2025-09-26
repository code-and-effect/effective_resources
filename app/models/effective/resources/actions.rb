# frozen_string_literal: true

module Effective
  module Resources
    module Actions
      EMPTY_HASH = {}
      POST_VERBS = ['POST', 'PUT', 'PATCH']
      CRUD_ACTIONS = %i(index new create show edit update destroy)

      # This will have been set by init from crud_controller, or from a class and namespace
      def controller_path
        @controller_path ||= route_name #[namespace, plural_name].compact * '/')
      end

      def route_engines
        if tenant? && Tenant.current.present?
          [Rails.application, Tenant.Engine] + (Rails::Engine.subclasses.reverse - Tenant.route_engines)
        else
          [Rails.application] + Rails::Engine.subclasses.reverse
        end
      end

      def routes
        @routes ||= begin
          routes = nil

          engines = route_engines()

          # Check from controller_path. This is generally correct.
          engines.each do |engine|
            routes = engine.routes.routes.select do |route|
              controller_path == route.defaults[:controller] && !(route.name || '').end_with?('root')
            end

            if routes.present?
              @routes_app = engine; break
            end
          end

          if routes.blank?
            matches = route_name_fallbacks()

            engines.each do |engine|
              routes = engine.routes.routes.select do |route|
                (matches & [route.defaults[:controller]]).present? && !(route.name || '').end_with?('root')
              end

              if routes.present?
                @routes_app = engine; break
              end
            end
          end

          Array(routes).inject({}) { |h, route| h[route.defaults[:action].to_sym] = route; h }
        end
      end

      def routes_app
        @routes_app if routes.present?
      end

      def url_helpers
        (routes_app || Rails.application).routes.url_helpers
      end

      # Effective::Resource.new('admin/posts').action_path_helper(:edit) => 'edit_admin_posts_path'
      # This will return empty for create, update and destroy
      def action_path_helper(action)
        return unless routes[action]
        return (routes[action].name + '_path') if routes[action].name.present?
      end

      # Effective::Resource.new('admin/posts').action_path(:edit, Post.last) => '/admin/posts/3/edit'
      # Will work for any action. Returns the real path
      def action_path(action, resource = nil, opts = nil)
        opts ||= EMPTY_HASH

        if klass.nil? && resource.present? && initialized_name.kind_of?(ActiveRecord::Reflection::BelongsToReflection)
          return Effective::Resource.new(resource, namespace: namespace).action_path(action, resource, opts)
        end

        return unless routes[action]

        if resource.kind_of?(Hash)
          opts = resource; resource = nil
        end

        # edge case: Effective::Resource.new('admin/comments').action_path(:new, @post)
        if resource && klass && !resource.kind_of?(klass)
          if (bt = belongs_to(resource)).present? && instance.respond_to?("#{bt.name}=")
            return routes[action].format(klass.new(bt.name => resource)).presence
          end
        end

        target = (resource || instance)

        formattable = if routes[action].parts.include?(:id)
          if target.respond_to?(:to_param) && target.respond_to?(:id) && (target.to_param != target.id.to_s)
            routes[action].parts.each_with_object({}) do |part, h|
              if part == :id
                h[part] = target.to_param
              elsif part == :format
                # Nothing
              elsif target.respond_to?(part)
                obj = if part.to_s.ends_with?('_id') && target.respond_to?(part.to_s.chomp('_id'))
                  target.try("#{part.to_s.chomp('_id')}")
                end

                h[part] = obj.try(:to_param) || target.public_send(part)
              end
            end
          elsif target.respond_to?(:to_param) || target.respond_to?(:id)
            target
          else
            {id: target}
          end
        end

        # Generate the path
        path = (routes[action].format(formattable || EMPTY_HASH) rescue nil)

        if path.present? && opts.present?
          uri = URI.parse(path)
          uri.query = URI.encode_www_form(opts)
          path = uri.to_s
        end

        path
      end

      def actions
        @route_actions ||= routes.keys
      end

      def crud_actions
        (actions & CRUD_ACTIONS)
      end

      # GET actions
      def collection_actions
        routes.map { |_, route| route.defaults[:action].to_sym if is_collection_route?(route) } - [nil]
      end

      def collection_get_actions
        routes.map { |_, route| route.defaults[:action].to_sym if is_collection_route?(route) && is_get_route?(route) } - [nil]
      end

      def collection_post_actions
        routes.map { |_, route| route.defaults[:action].to_sym if is_collection_route?(route) && is_post_route?(route) } - [nil]
      end

      # All actions
      def member_actions
        routes.map { |_, route| route.defaults[:action].to_sym if is_member_route?(route) } - [nil]
      end

      # GET actions
      def member_get_actions
        routes.map { |_, route| route.defaults[:action].to_sym if is_member_route?(route) && is_get_route?(route) } - [nil]
      end

      def member_delete_actions
        routes.map { |_, route| route.defaults[:action].to_sym if is_member_route?(route) && is_delete_route?(route) } - [nil]
      end

      # POST/PUT/PATCH actions
      def member_post_actions
        routes.map { |_, route| route.defaults[:action].to_sym if is_member_route?(route) && is_post_route?(route) } - [nil]
      end

      private

      def is_member_route?(route)
        (route.path.required_names || []).include?('id')
      end

      def is_collection_route?(route)
        (route.path.required_names || []).include?('id') == false
      end

      def is_get_route?(route)
        route.verb == 'GET'
      end

      def is_delete_route?(route)
        route.verb == 'DELETE'
      end

      def is_post_route?(route)
        POST_VERBS.include?(route.verb)
      end
    end
  end
end
