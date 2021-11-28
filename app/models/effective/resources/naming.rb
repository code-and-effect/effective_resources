module Effective
  module Resources
    module Naming
      SPLIT = /\/|::/  # / or ::

      def name # 'post'
        @name ||= ((klass.present? ? klass.name : initialized_name).to_s.split(SPLIT).last || '').singularize.underscore
      end

      def plural_name # 'posts'
        name.pluralize
      end

      def resource_name # 'effective_post' used by permitted params
        @resource_name ||= ((klass.present? ? klass.name : initialized_name).to_s.split(SPLIT).join('_') || '').singularize.underscore
      end

      def initialized_name
        @initialized_name
      end

      # There could be a few, this is the best guess.
      def route_name # 'post' initialized from the controller_path/initialized_name and not the class
        names = class_name.split('::')

        if names.length > 1
          Array(names[0]) + namespaces + Array(names[1..-1])
        else
          namespaces + names
        end.compact.map(&:downcase).join('/').pluralize
      end

      def route_name_fallbacks
        mod = class_name.split('::').first.to_s.downcase
        admin = ('admin' if namespace.present? && namespace.include?('/admin'))

        matches = [
          route_name.singularize,
          [*namespace, plural_name].join('/'),
          [*admin, plural_name].join('/'),
          [*namespace, name].join('/'),
          [*admin, name].join('/'),
          [*mod, *namespace, plural_name].join('/'),
          [*mod, *namespace, name].join('/')
        ]
      end

      def class_name # 'Effective::Post'
        @model_klass ? @model_klass.name : name.classify
      end

      def class_path # 'effective'
        class_name.split('::')[0...-1].map { |name| name.underscore } * '/'
      end

      def namespace # 'admin/things'
        (namespaces.join('/') if namespaces.present?)
      end

      def namespaces # ['admin', 'things']
        @namespaces || []
      end

      def human_name
        name.gsub('::', ' ').underscore.gsub('_', ' ')
      end

      def human_plural_name
        name.pluralize.gsub('::', ' ').underscore.gsub('_', ' ')
      end
    end
  end
end
