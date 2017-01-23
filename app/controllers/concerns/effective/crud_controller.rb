module Effective
  module CrudController
    extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
    end

    def index
      @page_title ||= resource_plural_name.titleize
      EffectiveResources.authorized?(self, :index, resource_class)

      self.resources ||= resource_class.all

      if resource_datatable_class
        @datatable ||= resource_datatable_class.new(params[:scopes])
      end
    end

    def new
      self.resource ||= resource_class.new

      @page_title ||= "New #{resource_name.titleize}"
      EffectiveResources.authorized?(self, :new, resource)
    end

    def create
      self.resource ||= resource_class.new(send(resource_params_method_name))

      @page_title ||= "New #{resource_name.titleize}"
      EffectiveResources.authorized?(self, :create, resource)

      if resource.save
        flash[:success] = "Successfully created #{resource_name}"
        redirect_to(resource_redirect_path)
      else
        flash.now[:danger] = "Unable to create #{resource_name}: #{resource.errors.full_messages.to_sentence}"
        render :new
      end
    end

    def show
      self.resource ||= resource_class.find(params[:id])

      @page_title ||= resource.to_s
      EffectiveResources.authorized?(self, :show, resource)
    end

    def edit
      self.resource ||= resource_class.find(params[:id])

      @page_title ||= "Edit #{resource}"
      EffectiveResources.authorized?(self, :edit, resource)
    end

    def update
      self.resource ||= resource_class.find(params[:id])

      @page_title = "Edit #{resource}"
      EffectiveResources.authorized?(self, :update, resource)

      if resource.update_attributes(send(resource_params_method_name))
        flash[:success] = "Successfully updated #{resource_name}"
        redirect_to(resource_redirect_path)
      else
        flash.now[:danger] = "Unable to update #{resource_name}: #{resource.errors.full_messages.to_sentence}"
        render :edit
      end
    end

    def destroy
      self.resource = resource_class.find(params[:id])

      @page_title = "Destroy #{resource}"
      EffectiveResources.authorized?(self, :destroy, resource)

      if resource.destroy
        flash[:success] = "Successfully deleted #{resource_name}"
      else
        flash[:danger] = "Unable to delete #{resource_name}: #{resource.errors.full_messages.to_sentence}"
      end

      request.referer.present? ? redirect_to(request.referer) : redirect_to(send(resource_index_path))
    end

    protected

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

    def resource_class # Thing
      effective_resource.klass
    end

    def resource_name # 'thing'
      effective_resource.name
    end

    def resource_plural_name # 'things'
      effective_resource.plural_name
    end

    def resource_datatable_class # ThingsDatatable
      effective_resource.datatable_klass
    end

    def resource_params_method_name
      ["#{resource_name}_params", "#{resource_plural_name}_params", 'permitted_params'].find { |name| respond_to?(name, true) } || 'params'
    end

    def resource_index_path
      effective_resource.index_path
    end

    def resource_redirect_path
      case params[:commit].to_s
      when 'Save'               ; send(effective_resource.edit_path, resource)
      when 'Save and Continue'  ; send(effective_resource.index_path)
      when 'Save and Add New'   ; send(effective_resource.new_path)
      else send(effective_resource.show_path, resource)
      end
    end

    private

    def effective_resource
      @_effective_resource ||= Effective::Resource.new(controller_path)
    end

  end
end
