module Effective
  module Resources
    module Rest

      def index_path
        [namespace, plural_name, 'path'].compact * '_'
      end

      def new_path
        ['new', namespace, name, 'path'].compact * '_'
      end

      def show_path
        [namespace, name, 'path'].compact * '_'
      end

      def edit_path
        ['edit', namespace, name, 'path'].compact * '_'
      end

    end
  end
end
