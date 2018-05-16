module EffectiveResources
  class Engine < ::Rails::Engine
    engine_name 'effective_resources'

    config.autoload_paths += Dir["#{config.root}/lib/", "#{config.root}/app/controllers/concerns/effective/"]

    # Set up our default configuration options.
    initializer 'effective_resources.defaults', before: :load_config_initializers do |app|
      eval File.read("#{config.root}/config/effective_resources.rb")
    end

    # Register the flash_messages concern so that it can be called in ActionController
    initializer 'effective_resources.action_controller' do |app|
      ActiveSupport.on_load :action_controller do
        include(Effective::FlashMessages)
      end
    end

    # Include acts_as_addressable concern and allow any ActiveRecord object to call it
    initializer 'effective_resources.active_record' do |app|
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.extend(ActsAsTokened::ActiveRecord)
      end
    end

  end
end
