# frozen_string_literal: true

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
      define_callbacks :resource_render, :resource_before_save, :resource_after_save, :resource_after_commit, :resource_error
      layout -> { resource_layout }
    end

    module ClassMethods
      include Effective::CrudController::Dsl

      def effective_crud_controller?; true; end
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

    def effective_resource(safe: false)
      @_effective_resource ||= begin
        relation = instance_exec(&resource_scope_relation) if respond_to?(:resource_scope_relation)

        if respond_to?(:resource_scope_relation)
          unless relation.kind_of?(ActiveRecord::Relation) || (relation.kind_of?(Class) && relation.ancestors.include?(ActiveModel::Model))
            raise('resource_scope must return an ActiveRecord::Relation or class including ActiveModel::Model')
          end
        end

        resource = Effective::Resource.new(controller_path, relation: relation)

        unless resource.relation.kind_of?(ActiveRecord::Relation) || resource.active_model?
          raise("unable to build resource_scope for #{resource.klass || 'unknown klass'}. Please name your controller to match an existing model, or manually define a resource_scope.") unless safe
        else
          resource
        end
      end
    end

    def action_missing(action, *args, &block)
      effective_resource = self.effective_resource(safe: true)
      return super if effective_resource.blank?

      action = action.to_sym

      if effective_resource.member_actions.include?(action)
        return member_action(action)
      end

      if effective_resource.collection_actions.include?(action)
        return collection_action(action)
      end

      params[:id].present? ? member_action(action) : collection_action(action)
    end

    def resource_klass # Thing
      effective_resource.klass
    end

    private

    def resource_scope
      relation = effective_resource.relation

      # Apply jit_preloader if present
      if defined?(JitPreloader) && EffectiveResources.use_jit_preloader && relation.respond_to?(:includes_values)
        relation.includes_values = [] # Removes any previously defined .includes()
        relation.jit_preload
      else
        (relation.try(:deep) || relation)
      end
    end

    def resource_name # 'thing'
      effective_resource.name
    end

    def resource_name_id
      (effective_resource.name + '_id').to_sym
    end

    def resource_plural_name # 'things'
      effective_resource.plural_name
    end

    def resource_human_name # I18n
      effective_resource.human_name
    end

    def resource_human_plural_name # I18n
      effective_resource.human_plural_name
    end

    def resource_datatable_attributes
      resource_scope.where_values_hash.symbolize_keys
    end

    def resource_datatable
      # This might have been done from a before action or dsl method
      unless @datatable.nil?
        raise('expected @datatable to be an Effective::Datatable') unless @datatable.kind_of?(Effective::Datatable)

        @datatable.effective_resource = effective_resource
        return @datatable
      end

      datatable_klass = effective_resource.datatable_klass
      return unless datatable_klass.present?

      datatable = EffectiveResources.best(datatable_klass.name).new(resource_datatable_attributes)
      datatable.effective_resource = effective_resource if datatable.respond_to?(:effective_resource=)
      datatable
    end

    def resource_layout
      namespace = controller_path.include?('admin/') ? 'admin' : 'application'

      if defined?(Tenant)
        return "#{Tenant.current}/#{namespace}"
      end

      namespace
    end

    def resource_params_method_name
      ['permitted_params', "#{resource_name}_params", "#{resource_plural_name}_params"].each do |name|
        return name if respond_to?(name, true)
      end

      # Built in ones
      return 'resource_admin_permitted_params' if effective_resource.model.present? && effective_resource.namespaces == ['admin']
      return 'resource_permitted_params' if effective_resource.model.present?
      return 'resource_active_model_permitted_params' if effective_resource.active_model?

      # Fallback
      'params'
    end

  end
end
