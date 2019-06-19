module Effective
  module Resources
    module Controller

      # Used by effective_form_submit
      # The actions we would use to commit. For link_to
      # { 'Save': { action: :save }, 'Continue': { action: :save }, 'Add New': { action: :save }, 'Approve': { action: :approve } }
      # Saves a list of commit actions...
      def submits
        {}.tap do |submits|
          if actions.find { |a| a == :create || a == :update } && EffectiveResources.default_submits['Save']
            submits['Save'] = { action: :save, default: true }
          end

          if actions.find { |a| a == :index } && EffectiveResources.default_submits['Continue']
            submits['Continue'] = { action: :save, redirect: :index, default: true, unless: -> { params[:_datatable_id].present? } }
          end

          if actions.find { |a| a == :new } && EffectiveResources.default_submits['Add New']
            submits['Add New'] = { action: :save, redirect: :new, default: true, unless: -> { params[:_datatable_id].present? } }
          end
        end
      end

      def buttons
        {}.tap do |buttons|
          member_get_actions.each do |action| # default true means it will be overwritten by dsl methods
            buttons[action.to_s.titleize] = { action: action, default: true }
          end

          (member_post_actions - crud_actions).each do |action| # default true means it will be overwritten by dsl methods
            buttons[action.to_s.titleize] = case action
            when :archive
              { action: action, default: true, if: -> { !resource.archived? }, class: 'btn btn-danger', 'data-method' => :post, 'data-confirm' => "Really #{action} @resource?"}
            when :unarchive
              { action: action, default: true, if: -> { resource.archived? }, 'data-method' => :post, 'data-confirm' => "Really #{action} @resource?" }
            else
              { action: action, default: true, 'data-method' => :post, 'data-confirm' => "Really #{action} @resource?"}
            end
          end

          member_delete_actions.each do |action|
            if action == :destroy
              next if buttons.values.find { |v| v[:action] == :archive }.present?
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
          (member_get_actions & crud_actions).reverse_each do |action|
            actions[action.to_s.titleize] = { action: action, default: true }
          end

          (member_get_actions - crud_actions).each do |action|
            actions[action.to_s.titleize] = { action: action, default: true }
          end

          (member_post_actions - crud_actions).each do |action|
            actions[action.to_s.titleize] = { action: action, default: true, 'data-method' => :post, 'data-confirm' => "Really #{action} @resource?" }

            actions[action.to_s.titleize] = case action
            when :archive
              { action: action, default: true, if: -> { resource.archived? }, class: 'btn btn-danger', 'data-method' => :post, 'data-confirm' => "Really #{action} @resource?"}
            when :unarchive
              { action: action, default: true, if: -> { resource.archived? }, 'data-method' => :post, 'data-confirm' => "Really #{action} @resource?" }
            else
              { action: action, default: true, 'data-method' => :post, 'data-confirm' => "Really #{action} @resource?" }
            end
          end

          member_delete_actions.each do |action|
            if action == :destroy
              next if actions.values.find { |v| v[:action] == :archive }.present?
              actions['Delete'] = { action: action, default: true, 'data-method' => :delete, 'data-confirm' => "Really delete @resource?" }
            else
              actions[action.to_s.titleize] = { action: action, default: true, 'data-method' => :delete, 'data-confirm' => "Really #{action} @resource?" }
            end
          end
        end
      end

      # Used by datatables
      def fallback_resource_actions
        {
          'Show': { action: :show, default: true },
          'Edit': { action: :edit, default: true },
          'Delete': { action: :destroy, default: true, 'data-method' => :delete, 'data-confirm' => "Really delete @resource?" }
        }
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
