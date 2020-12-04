module Effective
  module WizardController
    extend ActiveSupport::Concern

    include Wicked::Wizard
    include Effective::CrudController

    include Effective::WizardController::Actions

    included do
      before_action :redirect_if_blank_step, only: [:show]
      before_action :assign_wizard_resource, only: [:show, :update]
    end

    def resource_wizard_steps
      effective_resource.klass.const_get(:WIZARD_STEPS).keys
    end

    def resource_wizard_path(resource, step)
      path_helper = effective_resource.action_path_helper(:show).to_s.sub('_path', '_build_path')
      public_send(path_helper, resource, step)
    end

    def assign_wizard_resource
      self.resource ||= wizard_resource
    end

    def wizard_resource
      if params[resource_name_id] && params[resource_name_id] != 'new'
        resource_scope.find(params[resource_name_id])
      else
        resource_scope.new
      end
    end

  #   module ClassMethods
  #     include Effective::CrudController::Dsl

  #     def effective_resource
  #       @_effective_resource ||= Effective::Resource.new(controller_path)
  #     end

  #   end

  #   def resource # @thing
  #     instance_variable_get("@#{resource_name}")
  #   end

  #   def resource=(instance)
  #     instance_variable_set("@#{resource_name}", instance)
  #   end

  #   def resources # @things
  #     send(:instance_variable_get, "@#{resource_plural_name}")
  #   end

  #   def resources=(instance)
  #     send(:instance_variable_set, "@#{resource_plural_name}", instance)
  #   end

  #   def effective_resource
  #     self.class.effective_resource
  #   end

  #   private

  #   def resource_name # 'thing'
  #     effective_resource.name
  #   end

  #   def resource_klass # Thing
  #     effective_resource.klass
  #   end

  #   def resource_plural_name # 'things'
  #     effective_resource.plural_name
  #   end

  #   # Returns an ActiveRecord relation based on the computed value of `resource_scope` dsl method
  #   def resource_scope # Thing
  #     @_effective_resource_relation ||= (
  #       relation = case @_effective_resource_scope  # If this was initialized by the resource_scope before_action
  #       when ActiveRecord::Relation
  #         @_effective_resource_scope
  #       when Hash
  #         effective_resource.klass.where(@_effective_resource_scope)
  #       when Symbol
  #         effective_resource.klass.send(@_effective_resource_scope)
  #       when nil
  #         effective_resource.klass.respond_to?(:all) ? effective_resource.klass.all : effective_resource.klass
  #       else
  #         raise "expected resource_scope method to return an ActiveRecord::Relation or Hash"
  #       end

  #       unless relation.kind_of?(ActiveRecord::Relation) || effective_resource.active_model?
  #         raise("unable to build resource_scope for #{effective_resource.klass || 'unknown klass'}. Please name your controller to match an existing model, or manually define a resource_scope.")
  #       end

  #       relation
  #     )
  #   end

  #   def resource_datatable_attributes
  #     resource_scope.where_values_hash.symbolize_keys
  #   end

  #   def resource_datatable(action)
  #     datatable_klass = if action == :index
  #       effective_resource.datatable_klass
  #     else # Admin::ActionDatatable.new
  #       "#{[effective_resource.namespace.to_s.classify.presence, action.to_s.classify].compact.join('::')}Datatable".safe_constantize ||
  #       "#{[effective_resource.namespace.to_s.classify.presence, action.to_s.pluralize.classify].compact.join('::')}Datatable".safe_constantize ||
  #       "#{[effective_resource.namespace.to_s.classify.presence, action.to_s.singularize.classify].compact.join('::')}Datatable".safe_constantize
  #     end

  #     return unless datatable_klass.present?

  #     datatable = datatable_klass.new(resource_datatable_attributes)
  #     datatable.effective_resource = effective_resource if datatable.respond_to?(:effective_resource=)
  #     datatable
  #   end

  #   def resource_params_method_name
  #     ["#{resource_name}_params", "#{resource_plural_name}_params", 'permitted_params', 'effective_resource_permitted_params', ('resource_permitted_params' if effective_resource.model.present?)].compact.find { |name| respond_to?(name, true) } || 'params'
  #   end

  end
end
