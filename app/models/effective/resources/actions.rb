module Effective
  module Resources
    module Actions

      # This was written for the Edit actions fallback templates and Datatables
      # Effective::Resource.new('admin/posts').routes[:index]
      def routes
        @routes ||= (
          matches = [[namespace, plural_name].compact.join('/'.freeze), [namespace, name].compact.join('/'.freeze)]

          routes_engine.routes.routes.select do |route|
            matches.any? { |match| match == route.defaults[:controller] } && !route.name.to_s.end_with?('root')
          end.inject({}) do |h, route|
            h[route.defaults[:action].to_sym] = route; h
          end
        )
      end

      # Effective::Resource.new('effective/order', namespace: :admin)
      def routes_engine
        case class_name
        when 'Effective::Order'.freeze
          EffectiveOrders::Engine
        else
          Rails.application
        end
      end

      # Effective::Resource.new('admin/posts').action_path_helper(:edit) => 'edit_admin_posts_path'
      # This will return empty for create, update and destroy
      def action_path_helper(action)
        return unless routes[action]
        return (routes[action].name + '_path'.freeze) if routes[action].name.present?
      end

      # Effective::Resource.new('admin/posts').action_path(:edit, Post.last) => '/admin/posts/3/edit'
      # Will work for any action. Returns the real path
      def action_path(action, resource = nil, opts = {})
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

        # This generates the correct route when an object is overriding to_param
        if (resource || instance).respond_to?(:attributes)
          formattable = (resource || instance).attributes.symbolize_keys.merge(id: (resource || instance).to_param)
        end

        path = routes[action].format(formattable || {}).presence

        if path.present? && opts.present?
          uri = URI.parse(path)
          uri.query = URI.encode_www_form(opts)
          path = uri.to_s
        end

        path
      end

      def actions
        routes.keys
      end

      def crud_actions
        actions & %i(index new create show edit update destroy)
      end

      # GET actions
      def collection_actions
        routes.values.map { |route| route.defaults[:action].to_sym if is_collection_route?(route) }.compact
      end

      def collection_get_actions
        routes.values.map { |route| route.defaults[:action].to_sym if is_collection_route?(route) && is_get_route?(route) }.compact
      end

      def collection_post_actions
        routes.values.map { |route| route.defaults[:action].to_sym if is_collection_route?(route) && is_post_route?(route) }.compact
      end

      # All actions
      def member_actions
        routes.values.map { |route| route.defaults[:action].to_sym if is_member_route?(route) }.compact
      end

      # GET actions
      def member_get_actions
        routes.values.map { |route| route.defaults[:action].to_sym if is_member_route?(route) && is_get_route?(route) }.compact
      end

      def member_delete_actions
        routes.values.map { |route| route.defaults[:action].to_sym if is_member_route?(route) && is_delete_route?(route) }.compact
      end

      # POST/PUT/PATCH actions
      def member_post_actions
        routes.values.map { |route| route.defaults[:action].to_sym if is_member_route?(route) && is_post_route?(route) }.compact
      end

      # Same as controller_path in the view
      def controller_path
        [namespace, plural_name].compact * '/'.freeze
      end

      private

      def is_member_route?(route)
        (route.path.required_names || []).include?('id'.freeze)
      end

      def is_collection_route?(route)
        (route.path.required_names || []).include?('id'.freeze) == false
      end

      def is_get_route?(route)
        route.verb.to_s.include?('GET'.freeze)
      end

      def is_delete_route?(route)
        route.verb.to_s.include?('DELETE'.freeze)
      end

      def is_post_route?(route)
        ['POST', 'PUT', 'PATCH'].freeze.any? { |verb| route.verb == verb }
      end
    end
  end
end



