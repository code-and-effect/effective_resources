module Effective
  module Resources
    module Controller

      # Used by effective_form_submit
      # The actions we would use to commit. For link_to
      # { 'Save': { action: :save }, 'Continue': { action: :save }, 'Add New': { action: :save }, 'Approve': { action: :approve } }
      # Saves a list of commit actions...
      def submits
        @submits ||= {}.tap do |submits|
          if (actions.find { |a| a == :create } || actions.find { |a| a == :update })
            submits['Save'] = { action: :save, default: true }
          end

          if actions.find { |a| a == :index }
            submits['Continue'] = { action: :save, default: true, redirect: :index }
          end

          if actions.find { |a| a == :new }
            submits['Add New'] = { action: :save, default: true, redirect: :new }
          end
        end
      end

      def buttons
        @buttons ||= {}.tap do |buttons|
          (member_actions - crud_actions).each do |action| # default true means it will be overwritten by dsl methods
            buttons[action.to_s.titleize] = { action: action, default: true }
          end
        end
      end

      def ons
        @ons ||= {}
      end


    end
  end
end
