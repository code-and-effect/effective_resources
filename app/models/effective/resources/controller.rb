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

      # Here we look at all available (class level) member actions, see which ones apply to the current resource
      # This feeds into the helper simple_form_submit(f)
      # Returns a Hash of {'Save': {class: 'btn btn-primary'}, 'Approve': {class: 'btn btn-secondary'}}
      def submits_for(obj, controller:)
        submits.select do |commit, args|
          args[:class] = args[:class].to_s

          action = (args[:action] == :save ? (obj.new_record? ? :create : :update) : args[:action])

          (args.key?(:if) ? obj.instance_exec(&args[:if]) : true) &&
          (args.key?(:unless) ? !obj.instance_exec(&args[:unless]) : true) &&
          EffectiveResources.authorized?(controller, action, obj)
        end.transform_values.with_index do |opts, index|
          if opts[:class].blank?
            if index == 0
              opts[:class] = 'btn btn-primary'
            elsif defined?(EffectiveBootstrap)
              opts[:class] = 'btn btn-secondary'
            else
              opts[:class] = 'btn btn-default'
            end
          end

          opts.except(:action, :default, :if, :unless, :redirect)
        end
      end

    end
  end
end
