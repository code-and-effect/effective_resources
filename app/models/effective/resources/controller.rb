# frozen_string_literal: true

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
        human_index = EffectiveResources.et("effective_resources.actions.index")
        human_new = EffectiveResources.et("effective_resources.actions.new")

        {}.tap do |buttons|
          member_get_actions.each do |action| # default true means it will be overwritten by dsl methods
            buttons[human_action_name(action)] = { action: action, default: true }
          end

          (member_post_actions - crud_actions).each do |action| # default true means it will be overwritten by dsl methods
            name = human_action_name(action)
            confirm = human_action_confirm(action)

            buttons[name] = case action
            when :archive
              { action: action, default: true, if: -> { !resource.archived? }, class: 'btn btn-danger', 'data-method' => :post, 'data-confirm' => confirm }
            when :unarchive
              { action: action, default: true, if: -> { resource.archived? }, 'data-method' => :post, 'data-confirm' => confirm }
            else
              { action: action, default: true, 'data-method' => :post, 'data-confirm' => confirm }
            end
          end

          member_delete_actions.each do |action|
            name = human_action_name(action)
            confirm = human_action_confirm(action)

            buttons[name] = { action: action, default: true, 'data-method' => :delete, 'data-confirm' => confirm }
          end

          if collection_get_actions.find { |a| a == :index }
            buttons["#{human_index} #{human_plural_name}"] = { action: :index, default: true }
          end

          if collection_get_actions.find { |a| a == :new }
            buttons["#{human_new} #{human_name}"] = { action: :new, default: true }
          end

          (collection_get_actions - crud_actions).each do |action|
            buttons[human_action_name(action)] = { action: action, default: true }
          end
        end
      end

      # This is the fallback for render_resource_actions when no actions are specified
      # It is used by datatables
      def resource_actions
        {}.tap do |actions|
          member_get_actions.reverse_each do |action|
            next unless crud_actions.include?(action)
            actions[human_action_name(action)] = { action: action, default: true }
          end

          member_get_actions.each do |action|
            next if crud_actions.include?(action)
            actions[human_action_name(action)] = { action: action, default: true }
          end

          member_post_actions.each do |action|
            next if crud_actions.include?(action)

            name = human_action_name(action)
            confirm = human_action_confirm(action)

            actions[name] = case action
            when :archive
              { action: action, default: true, if: -> { !resource.archived? }, class: 'btn btn-danger', 'data-method' => :post, 'data-confirm' => confirm }
            when :unarchive
              { action: action, default: true, if: -> { resource.archived? }, 'data-method' => :post, 'data-confirm' => confirm }
            else
              { action: action, default: true, 'data-method' => :post, 'data-confirm' => confirm }
            end
          end

          member_delete_actions.each do |action|
            name = human_action_name(action)
            confirm = human_action_confirm(action)

            actions[name] = { action: action, default: true, 'data-method' => :delete, 'data-confirm' => confirm }
          end
        end
      end

      # Used by datatables
      def fallback_resource_actions
        {
          human_action_name(:show) => { action: :show, default: true },
          human_action_name(:edit) => { action: :edit, default: true },
          human_action_name(:destroy) => { action: :destroy, default: true, 'data-method' => :delete, 'data-confirm' => human_action_confirm(:destroy) }
        }
      end

      # This is the fallback for render_resource_actions when no actions are specified, but a class is given
      # Used by Datatables new
      def resource_klass_actions
        human_index = EffectiveResources.et("effective_resources.actions.index")
        human_new = EffectiveResources.et("effective_resources.actions.new")

        {}.tap do |buttons|
          if collection_get_actions.find { |a| a == :index }
            buttons["#{human_index} #{human_plural_name}"] = { action: :index, default: true }
          end

          if collection_get_actions.find { |a| a == :new }
            buttons["#{human_new} #{human_name}"] = { action: :new, default: true }
          end

          (collection_get_actions - crud_actions).each do |action|
            buttons[human_action_name(action)] = { action: action, default: true }
          end
        end
      end

      def ons
        {}
      end

    end
  end
end
