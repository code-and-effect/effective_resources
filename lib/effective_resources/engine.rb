module EffectiveResources
  class Engine < ::Rails::Engine
    engine_name 'effective_resources'

    config.autoload_paths += Dir["#{config.root}/lib/", "#{config.root}/app/controllers/concerns/effective/"]

    # Set up our default configuration options.
    initializer 'effective_resources.defaults', before: :load_config_initializers do |app|
      eval File.read("#{config.root}/config/effective_resources.rb")
    end

  end
end
