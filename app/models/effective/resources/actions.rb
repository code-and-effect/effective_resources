module Effective
  module Resources
    module Actions

      # This was written for the Edit actions fallback templates

      def controller_routes
        @controller_routes ||= (
          path = controller_path

          Rails.application.routes.routes.select do |route|
            (route.defaults[:controller] == path) && route.defaults[:action].present?
          end
        )
      end

      def controller_actions
        controller_routes.map { |route| route.defaults[:action] }
      end

      # GET actions
      def member_actions
        controller_routes.map { |route| route.defaults[:action] if is_get_member?(route) }.compact - crud_actions
      end

      # GET actions
      def member_post_actions
        controller_routes.map { |route| route.defaults[:action] if is_post_member?(route) }.compact - crud_actions
      end

      # Same as controller_path in the view
      def controller_path
        [namespace, plural_name].compact * '/'
      end

      private

      def crud_actions
        %w(index new create show edit update destroy)
      end

      def is_get_member?(route)
        route.verb.to_s.include?('GET') && route.path.required_names == ['id']
      end

      def is_post_member?(route)
        ['POST', 'PUT', 'PATCH'].any? { |verb| route.verb == verb } && route.path.required_names == ['id']
      end

    end
  end
end



