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
      define_callbacks :resource_render, :resource_before_save, :resource_after_save, :resource_after_commit, :resource_error
    end

    module ClassMethods
      include Effective::CrudController::Dsl

      # This is used to define_actions_from_routes and for the buttons/submits/ons
      # It doesn't really work with the resource_scope correctly but the routes are important here
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
      @_effective_resource ||= begin
        relation = resource_scope_relation.call() if respond_to?(:resource_scope_relation)

        if respond_to?(:resource_scope_relation) && !relation.kind_of?(ActiveRecord::Relation)
          raise('resource_scope must return an ActiveRecord::Relation')
        end

        Effective::Resource.new(controller_path, relation: relation)
      end
    end

    private

    def resource_scope
      @_effective_resource_scope ||= begin
        relation = effective_resource.relation

        unless relation.kind_of?(ActiveRecord::Relation) || effective_resource.active_model?
          raise("unable to build resource_scope for #{effective_resource.klass || 'unknown klass'}. Please name your controller to match an existing model, or manually define a resource_scope.")
        end

        relation
      end
    end

    def resource_name # 'thing'
      effective_resource.name
    end

    def resource_name_id
      (effective_resource.name + '_id').to_sym
    end

    def resource_klass # Thing
      effective_resource.klass
    end

    def resource_plural_name # 'things'
      effective_resource.plural_name
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
      datatable.effective_resource = effective_resource if datatable.respond_to?(:effective_resource=)
      datatable
    end

    def resource_params_method_name
      ['permitted_params', "#{resource_name}_params", "#{resource_plural_name}_params"].each do |name|
        return name if respond_to?(name, true)
      end

      # Built in ones
      return 'resource_permitted_params' if effective_resource.model.present?
      return 'resource_active_model_permitted_params' if effective_resource.active_model?

      # Fallback
      'params'
    end

  end
end
