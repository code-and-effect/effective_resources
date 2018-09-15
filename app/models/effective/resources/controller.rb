module Effective
  module Resources
    module Controller

      # Used by effective_form_submit
      # The actions we would use to commit. For link_to
      # { 'Save': { action: :save }, 'Continue': { action: :save }, 'Add New': { action: :save }, 'Approve': { action: :approve } }
      # Saves a list of commit actions...
      def submits
        {}.tap do |submits|
          if (actions.find { |a| a == :create } || actions.find { |a| a == :update })
            submits['Save'] = { action: :save, default: true }
          end

          if actions.find { |a| a == :index }
            submits['Continue'] = { action: :save, redirect: :index, default: true, unless: -> { params[:_datatable_id] } }
          end

          if actions.find { |a| a == :new }
            submits['Add New'] = { action: :save, redirect: :new, default: true, unless: -> { params[:_datatable_id] } }
          end
        end
      end

      def buttons
        {}.tap do |buttons|
          member_get_actions.each do |action| # default true means it will be overwritten by dsl methods
            buttons[action.to_s.titleize] = { action: action, default: true }
          end

          (member_post_actions - crud_actions).each do |action| # default true means it will be overwritten by dsl methods
            buttons[action.to_s.titleize] = { action: action, default: true, 'data-method' => :post, 'data-confirm' => "Really #{action} @reource?"}
          end

          member_delete_actions.each do |action|
            if action == :destroy
              buttons['Delete'] = { action: action, default: true, 'data-method' => :delete, 'data-confirm' => "Really delete @resource?" }
            else
              buttons[action.to_s.titleize] = { action: action, default: true, 'data-method' => :delete, 'data-confirm' => "Really #{action} @resource?" }
            end
          end

          if collection_get_actions.find { |a| a == :index }
            buttons["All #{human_plural_name}".titleize] = { action: :index, default: true }
          end

          if collection_get_actions.find { |a| a == :new }
            buttons["New #{human_name}".titleize] = { action: :new, default: true }
          end

          (collection_get_actions - crud_actions).each do |action|
            buttons[action.to_s.titleize] = { action: action, default: true }
          end
        end
      end

      # This is the fallback for render_resource_actions when no actions are specified
      # It is used by datatables
      def resource_actions
        {}.tap do |actions|
          (member_get_actions & crud_actions).each do |action|
            actions[action.to_s.titleize] = { action: action, default: true }
          end

          (member_get_actions - crud_actions).each do |action|
            actions[action.to_s.titleize] = { action: action, default: true }
          end

          (member_post_actions - crud_actions).each do |action|
            actions[action.to_s.titleize] = { action: action, default: true, 'data-method' => :post, 'data-confirm' => "Really #{action} @resource?" }
          end

          member_delete_actions.each do |action|
            if action == :destroy
              actions['Delete'] = { action: action, default: true, 'data-method' => :delete, 'data-confirm' => "Really delete @resource?" }
            else
              actions[action.to_s.titleize] = { action: action, default: true, 'data-method' => :delete, 'data-confirm' => "Really #{action} @resource?" }
            end
          end
        end
      end

      # This is the fallback for render_resource_actions when no actions are specified, but a class is given
      # Used by Datatables new
      def resource_klass_actions
        {}.tap do |buttons|
          if collection_get_actions.find { |a| a == :index }
            buttons["All #{human_plural_name}".titleize] = { action: :index, default: true }
          end

          if collection_get_actions.find { |a| a == :new }
            buttons["New #{human_name}".titleize] = { action: :new, default: true }
          end

          (collection_get_actions - crud_actions).each do |action|
            buttons[action.to_s.titleize] = { action: action, default: true }
          end
        end
      end

      def ons
        {}
      end

    end
  end
end
