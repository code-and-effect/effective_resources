module Effective
  module CrudController
    extend ActiveSupport::Concern

    include Effective::CrudController::Actions
    include Effective::CrudController::Paths
    include Effective::CrudController::PermittedParams
    include Effective::CrudController::Respond
    include Effective::CrudController::Save
    include Effective::CrudController::Submits

    included do
      define_actions_from_routes
      define_permitted_params_from_model
      define_callbacks :resource_render, :resource_before_save, :resource_after_save, :resource_after_commit, :resource_error
    end

    module ClassMethods
      include Effective::CrudController::Dsl

      def effective_resource
        @_effective_resource ||= Effective::Resource.new(controller_path)
      end

      # Automatically respond to any action defined via the routes file
      def define_actions_from_routes
        (effective_resource.member_actions - effective_resource.crud_actions).each do |action|
          define_method(action) { member_action(action) }
        end

        (effective_resource.collection_actions - effective_resource.crud_actions).each do |action|
          define_method(action) { collection_action(action) }
        end
      end

      def define_permitted_params_from_model
        if effective_resource.model.present?
          define_method(:effective_resource_permitted_params) { resource_permitted_params } # save.rb
        end

        if effective_resource.active_model?
          define_method(:effective_resource_permitted_params) { resource_active_model_permitted_params } # save.rb
        end
      end

    end

    def resource # @thing
      instance_variable_get("@#{resource_name}")
    end

    def resource=(instance)
      instance_variable_set("@#{resource_name}", instance)
    end

    def resources # @things
      send(:instance_variable_get, "@#{resource_plural_name}")
    end

    def resources=(instance)
      send(:instance_variable_set, "@#{resource_plural_name}", instance)
    end

    def effective_resource
      self.class.effective_resource
    end

    private

    def resource_name # 'thing'
      effective_resource.name
    end

    def resource_klass # Thing
      effective_resource.klass
    end

    def resource_plural_name # 'things'
      effective_resource.plural_name
    end

    # Returns an ActiveRecord relation based on the computed value of `resource_scope` dsl method
    def resource_scope # Thing
      @_effective_resource_relation ||= (
        relation = case @_effective_resource_scope  # If this was initialized by the resource_scope before_filter
        when ActiveRecord::Relation
          @_effective_resource_scope
        when Hash
          effective_resource.klass.where(@_effective_resource_scope)
        when Symbol
          effective_resource.klass.send(@_effective_resource_scope)
        when nil
          effective_resource.klass.respond_to?(:all) ? effective_resource.klass.all : effective_resource.klass
        else
          raise "expected resource_scope method to return an ActiveRecord::Relation or Hash"
        end

        unless relation.kind_of?(ActiveRecord::Relation) || effective_resource.active_model?
          raise("unable to build resource_scope for #{effective_resource.klass || 'unknown klass'}. Please name your controller to match an existing model, or manually define a resource_scope.")
        end

        relation
      )
    end

    def resource_datatable_attributes
      resource_scope.where_values_hash.symbolize_keys
    end

    def resource_datatable(action)
      datatable_klass = if action == :index
        effective_resource.datatable_klass
      else # Admin::ActionDatatable.new
        "#{[effective_resource.namespace.to_s.classify.presence, action.to_s.classify].compact.join('::')}Datatable".safe_constantize ||
        "#{[effective_resource.namespace.to_s.classify.presence, action.to_s.pluralize.classify].compact.join('::')}Datatable".safe_constantize ||
        "#{[effective_resource.namespace.to_s.classify.presence, action.to_s.singularize.classify].compact.join('::')}Datatable".safe_constantize
      end

      return unless datatable_klass.present?

      datatable = datatable_klass.new(resource_datatable_attributes)
      datatable.view = view_context

      datatable
    end

    def resource_params_method_name
      ["#{resource_name}_params", "#{resource_plural_name}_params", 'permitted_params', 'effective_resource_permitted_params', ('resource_permitted_params' if effective_resource.model.present?)].compact.find { |name| respond_to?(name, true) } || 'params'
    end

  end
end
