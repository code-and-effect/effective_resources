module Effective
  module Resources
    module Routes

      def routes
        @_resource_routes ||= (
          matches = [[namespace, plural_name].join('/'), [namespace, name].join('/')]

          Rails.application.routes.routes.select do |route|
            matches.any? { |match| match == route.defaults[:controller] }
          end.inject({}) do |h, route|
            h[route.defaults[:action].to_sym] = route; h
          end
        )
      end

      # def index_route(check: false)
      #   route = [namespace, plural_name, 'route'].compact * '_'
      #   route if (!check || route_exists?(route))
      # end

      # def new_route(check: false)
      #   route = ['new', namespace, name, 'route'].compact * '_'
      #   route if (!check || route_exists?(route))
      # end

      # def show_route(check: false)
      #   route = [namespace, name, 'route'].compact * '_'
      #   route if (!check || route_exists?(route, 1))
      # end

      # def destroy_route(check: false)
      #   route = [namespace, name, 'route'].compact * '_'
      #   route if (!check || route_exists?(route, 1, :delete))
      # end

      # def get_path(action:)
      #   route = routes.find { |route| route.defaults[:action] == action }
      #   binding.pry

      #   return unless route

      #   return unless EffectiveResources.authorized?(self, action, instance)

      #   routes.url_helpers.send(route.name, instance)
      # end

      def action_path(action, resource = nil, opts = {})
        return unless routes[action]

        path = (routes[action].name + '_path')
        resources = [] # We build up this array with the resources needed to be passed to _path helper

        routes[action].parts.reverse_each do |part|
          next if opts.key?(part)

          obj = resources.find { |obj| obj.respond_to?(part) } || resource
          next unless obj.respond_to?(part)

          if part == :id
            resources << obj
          elsif part.to_s.end_with?('_id')
            resources << (obj.send(part.to_s[0...-3]) || obj.send(part))
          else
            resources << obj.send(part)
          end
        end

        Rails.application.routes.url_helpers.send(path, *resources.reverse.compact, opts)
      end

      def route_exists?(path, param = nil, verb = :get)
        routes = Rails.application.routes

        return false unless routes.url_helpers.respond_to?(path)
        (routes.recognize_path(routes.url_helpers.send(path, param), method: verb).present? rescue false)
      end

      def show_route
        routes.find { |route| route.defaults[:action] == :show }
      end

      def destroy_route
        routes.find { |route| route.defaults[:action] == :destroy }
      end

      # def edit_path
      #   raise 'expected to have @instance here' unless instance.persisted?
      # end

      # def action_route(action, check: false)
      #   route = [action, namespace, name, 'route'].compact * '_'
      #   route if (!check || route_exists?(route, 1, :any))
      # end

    end
  end
end
