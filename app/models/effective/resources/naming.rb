module Effective
  module Resources
    module Naming
      SPLIT = /\/|::/  # / or ::

      def name # 'post'
        @_name ||= @input_name.split(SPLIT).last.singularize
      end

      def plural_name # 'posts'
        @_plural_name ||= @input_name.split(SPLIT).last.pluralize
      end

      def class_name # 'Effective::Post'
        (@input_name.split(SPLIT) - namespaces).map { |name| name.classify } * '::'
      end

      def namespaced_class_name # 'Admin::Effective::Post'
        (namespaces.map { |name| name.classify } + [class_name]) * '::'
      end

      def namespace # 'admin/things'
        @_namespace ||= (namespaces.join('/') if namespaces.present?)
      end

      def namespaces # ['admin', 'things']
        @_namespaces ||= @input_name.split('/')[0...-1]
      end

    end
  end
end
