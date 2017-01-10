module EffectiveResources
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc 'Creates an EffectiveResources initializer in your application.'

      source_root File.expand_path('../../templates', __FILE__)

      def copy_initializer
        template ('../' * 3) + 'config/effective_resources.rb', 'config/initializers/effective_resources.rb'
      end

    end
  end
end
