module EffectiveResources
  class Engine < ::Rails::Engine
    engine_name 'effective_resources'

    config.autoload_paths += Dir[
      "#{config.root}/jobs/",
      "#{config.root}/lib/validators/",
      "#{config.root}/app/controllers/concerns/"
    ]

    config.eager_load_paths += Dir[
      "#{config.root}/jobs/",
      "#{config.root}/lib/validators/",
      "#{config.root}/app/controllers/concerns/"
    ]

    # Set up our default configuration options.
    initializer 'effective_resources.defaults', before: :load_config_initializers do |app|
      eval File.read("#{config.root}/config/effective_resources.rb")
    end

    # Include acts_as_addressable concern and allow any ActiveRecord object to call it
    initializer 'effective_resources.active_record' do |app|
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.extend(ActsAsArchived::Base)
        ActiveRecord::Base.extend(ActsAsTokened::Base)
        ActiveRecord::Base.extend(ActsAsSlugged::Base)
        ActiveRecord::Base.extend(ActsAsStatused::Base)
        ActiveRecord::Base.extend(ActsAsWizard::Base)

        ActiveRecord::Base.extend(EffectiveDeviseUser::Base)
        ActiveRecord::Base.extend(EffectiveResource::Base)
      end
    end

    initializer 'effective_resources.cancancan' do |app|
      ActiveSupport.on_load :active_record do
        if defined?(CanCan::Ability)
          CanCan::Ability.module_eval do
            CRUD_ACTIONS = [:index, :new, :create, :edit, :update, :show, :destroy]

            def crud
              CRUD_ACTIONS
            end
          end

          CanCan::Ability.include(ActsAsArchived::CanCan)
          CanCan::Ability.include(ActsAsStatused::CanCan)
        end
      end
    end

    # Register the acts_as_archived routes concern
    # resources :things, concerns: :acts_as_archived
    initializer 'effective_resources.routes_concern' do |app|
      ActionDispatch::Routing::Mapper.include(ActsAsArchived::RoutesConcern)

      # Doesn't seem to work with the on_load in rails 6.0
      #ActiveSupport.on_load :action_controller_base do
      #end
    end

    # Register the flash_messages concern so that it can be called in ActionController
    initializer 'effective_resources.action_controller' do |app|
      ActiveSupport.on_load :action_controller do
        include(Effective::FlashMessages)
      end
    end

  end
end
