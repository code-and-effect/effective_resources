module Effective
  module Resources
    module Naming
      SPLIT = /\/|::/  # / or ::

      def name # 'post'
        @name ||= @input_name.split(SPLIT).last.singularize
      end

      def plural_name # 'posts'
        name.pluralize
      end

      def class_name # 'Effective::Post'
        @class_name
      end

      def class_path # 'effective'
        class_name.split('::')[0...-1].map { |name| name.underscore } * '/'
      end

      def namespaced_class_name # 'Admin::Effective::Post'
        (namespaces.to_a.map { |name| name.classify } + [class_name]) * '::'
      end

      def namespace # 'admin/things'
        (namespaces.join('/') if namespaces.present?)
      end

      def namespaces # ['admin', 'things']
        @namespaces
      end

      def human_name
        class_name.gsub('::', ' ').underscore.gsub('_', ' ')
      end

    end
  end
end
