module Effective
  module Resources
    module Forms

      # Used by effective_form_submit
      # The actions we would use to commit. For link_to
      # { 'Save': { action: :save }, 'Continue': { action: :save }, 'Add New': { action: :save }, 'Approve': { action: :approve } }
      # Saves a list of commit actions...
      def submits
        @submits ||= {}.tap do |submits|
          if (actions.find { |a| a == :create } || actions.find { |a| a == :update })
            submits['Save'] = { action: :save, default: true, class: 'btn btn-primary' }
          end

          (member_post_actions - crud_actions).each do |action| # default true means it will be overwritten by dsl methods
            submits[action.to_s.titleize] = { action: action, default: true, class: 'btn btn-primary' }
          end

          if actions.find { |a| a == :index }
            submits['Continue'] = { action: :save, default: true, redirect: :index }
          end

          if actions.find { |a| a == :new }
            submits['Add New'] = { action: :save, default: true, redirect: :new }
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

      # Used by datatables
      def search_form_field(name, type = nil)
        case (type || sql_type(name))
        when :belongs_to
          { as: :select }.merge(search_form_field_collection(belongs_to(name)))
        when :belongs_to_polymorphic
          #{ as: :select, grouped: true, polymorphic: true, collection: nil}
          { as: :string }
        when :has_and_belongs_to_many
          { as: :select }.merge(search_form_field_collection(has_and_belongs_to_many(name)))
        when :has_many
          { as: :select, multiple: true }.merge(search_form_field_collection(has_many(name)))
        when :has_one
          { as: :select, multiple: true }.merge(search_form_field_collection(has_one(name)))
        when :effective_addresses
          { as: :string }
        when :effective_roles
          { as: :select, collection: EffectiveRoles.roles }
        when :effective_obfuscation
          { as: :effective_obfuscation }
        when :boolean
          { as: :boolean, collection: [['Yes', true], ['No', false]] }
        when :datetime
          { as: :datetime }
        when :date
          { as: :date }
        when :integer
          { as: :number }
        when :text
          { as: :text }
        when :time
          { as: :time }
        when ActiveRecord::Base
          { as: :select }.merge(Effective::Resource.new(type).search_form_field_collection)
        else
          name = name.to_s

          # If the method is named :status, and there is a Class::STATUSES
          if ((klass || NilClass).const_defined?(name.pluralize.upcase) rescue false)
            { as: :select, collection: klass.const_get(name.pluralize.upcase) }
          elsif ((klass || NilClass).const_defined?(name.singularize.upcase) rescue false)
            { as: :select, collection: klass.const_get(name.singularize.upcase) }
          else
            { as: :string }
          end
        end
      end

      def search_form_field_collection(association = nil, max_id = 1000)
        res = (association.nil? ? self : Effective::Resource.new(association))

        if res.max_id > max_id
          { as: :string }
        else
          if res.klass.unscoped.respond_to?(:datatables_scope)
            { collection: res.klass.datatables_scope.map { |obj| [obj.to_s, obj.to_param] } }
          elsif res.klass.unscoped.respond_to?(:datatables_filter)
            { collection: res.klass.datatables_filter.map { |obj| [obj.to_s, obj.to_param] } }
          elsif res.klass.unscoped.respond_to?(:sorted)
            { collection: res.klass.sorted.map { |obj| [obj.to_s, obj.to_param] } }
          else
            { collection: res.klass.all.map { |obj| [obj.to_s, obj.to_param] }.sort { |x, y| x[0] <=> y[0] } }
          end
        end
      end

    end
  end
end
