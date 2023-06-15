# frozen_string_literal: true

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
      app.config.to_prepare do
        ActiveRecord::Base.extend(ActsAsArchived::Base)
        ActiveRecord::Base.extend(ActsAsEmailForm::Base)
        ActiveRecord::Base.extend(ActsAsTokened::Base)
        ActiveRecord::Base.extend(ActsAsSlugged::Base)
        ActiveRecord::Base.extend(ActsAsStatused::Base)
        ActiveRecord::Base.extend(ActsAsPaginable::Base)
        ActiveRecord::Base.extend(ActsAsWizard::Base)
        ActiveRecord::Base.extend(ActsAsPurchasableWizard::Base)

        ActiveRecord::Base.extend(HasManyPurgable::Base)
        ActiveRecord::Base.extend(HasManyRichTexts::Base)

        ActiveRecord::Base.extend(EffectiveDeviseUser::Base)
        ActiveRecord::Base.extend(EffectiveResource::Base)
        ActiveRecord::Base.include(EffectiveAfterCommit::Base)
      end
    end

    initializer 'effective_resources.cancancan' do |app|
      app.config.to_prepare do
        if defined?(CanCan::Ability)
          CanCan::Ability.module_eval do
            CRUD_ACTIONS = [:index, :new, :create, :edit, :update, :show, :destroy]

            def crud
              CRUD_ACTIONS
            end
          end

          CanCan::Ability.include(ActsAsArchived::CanCan)
        end
      end
    end

    # Register the acts_as_archived routes concern
    # resources :things, concerns: :acts_as_archived
    initializer 'effective_resources.routes_concern' do |app|
      app.config.to_prepare do
        ActionDispatch::Routing::Mapper.include(ActsAsArchived::RoutesConcern)
      end
    end

    # Register the flash_messages concern so that it can be called in ActionController
    initializer 'effective_resources.action_controller' do |app|
      app.config.to_prepare do
        ActiveSupport.on_load :action_controller do
          include(Effective::FlashMessages)
        end
      end
    end

  end
end
