module Effective
  module Resources
    module Naming
      SPLIT = /\/|::/  # / or ::

      def klass # Effective::Post
        namespaced_class_name.safe_constantize || class_name.safe_constantize || name.constantize
      end

      def name # 'post'
        @input_name.split(SPLIT).last.singularize
      end

      def plural_name # 'posts'
        @input_name.split(SPLIT).last.pluralize
      end

      def class_name # 'Effective::Post'
        (@input_name.split(SPLIT) - namespaces).map { |name| name.classify } * '::'
      end

      def namespaced_class_name # 'Admin::Effective::Post'
        (namespaces.map { |name| name.classify } + [class_name]) * '::'
      end

      def namespace # 'admin/things'
        namespaces.join('/') if namespaces.present?
      end

      def namespaces # ['admin', 'things']
        @input_name.split('/')[0...-1]
      end

    end
  end
end
