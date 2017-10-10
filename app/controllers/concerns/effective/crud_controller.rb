module Effective
  module CrudController
    extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
      # Add the following to your controller for a simple member action
      # member_action :print
      def member_action(action)
        define_method(action) do
          self.resource ||= resource_scope.find(params[:id])

          EffectiveResources.authorized?(self, action, resource)

          @page_title ||= "#{action.to_s.titleize} #{resource}"

          member_post_action(action) unless request.get?
        end
      end

      def collection_action(action)
        define_method(action) do
          if params[:ids].present?
            self.resources ||= resource_scope.where(id: params[:ids])
          end

          if effective_resource.scope?(action)
            self.resources ||= resource_scope.public_send(action)
          end

          self.resources ||= resource_scope.all

          EffectiveResources.authorized?(self, action, resource_klass)

          @page_title ||= "#{action.to_s.titleize} #{resource_plural_name.titleize}"

          collection_post_action(action) unless request.get?
        end
      end

      # page_title 'My Title', only: [:new]
      def page_title(label = nil, opts = {}, &block)
        raise 'expected a label or block' unless (label || block_given?)

        instance_exec do
          before_action(opts) { @page_title ||= (block_given? ? instance_exec(&block) : label) }
        end
      end

      # resource_scope -> { current_user.things }
      # resource_scope -> { Thing.active.where(user: current_user) }
      # resource_scope do
      #   { user_id: current_user.id }
      # end

      # Return value should be:
      # a Relation: Thing.where(user: current_user)
      # a Hash: { user_id: current_user.id }
      def resource_scope(obj = nil, opts = {}, &block)
        raise 'expected a proc or block' unless (obj.respond_to?(:call) || block_given?)

        instance_exec do
          before_action(opts) do
            @_effective_resource_scope ||= instance_exec(&(block_given? ? block : obj))
          end
        end
      end

    end

    def index
      @page_title ||= resource_plural_name.titleize
      EffectiveResources.authorized?(self, :index, resource_klass)

      self.resources ||= resource_scope.all

      if resource_datatable_class
        @datatable ||= resource_datatable_class.new(self, resource_datatable_attributes)
      end
    end

    def new
      self.resource ||= resource_scope.new

      self.resource.assign_attributes(
        params.to_unsafe_h.except(:controller, :action).select { |k, v| resource.respond_to?("#{k}=") }
      )

      @page_title ||= "New #{resource_name.titleize}"
      EffectiveResources.authorized?(self, :new, resource)
    end

    def create
      self.resource ||= resource_scope.new(send(resource_params_method_name))

      @page_title ||= "New #{resource_name.titleize}"
      EffectiveResources.authorized?(self, :create, resource)

      resource.created_by ||= current_user if resource.respond_to?(:created_by=)

      if resource.save
        flash[:success] = flash_success(resource)
        redirect_to(resource_redirect_path)
      else
        flash.now[:danger] = flash_danger(resource)
        render :new
      end
    end

    def show
      self.resource ||= resource_scope.find(params[:id])

      @page_title ||= resource.to_s
      EffectiveResources.authorized?(self, :show, resource)
    end

    def edit
      self.resource ||= resource_scope.find(params[:id])

      @page_title ||= "Edit #{resource}"
      EffectiveResources.authorized?(self, :edit, resource)
    end

    def update
      self.resource ||= resource_scope.find(params[:id])

      @page_title = "Edit #{resource}"
      EffectiveResources.authorized?(self, :update, resource)

      if resource.update_attributes(send(resource_params_method_name))
        flash[:success] = flash_success(resource)
        redirect_to(resource_redirect_path)
      else
        flash.now[:danger] = flash_danger(resource)
        render :edit
      end
    end

    def destroy
      self.resource = resource_scope.find(params[:id])

      @page_title ||= "Destroy #{resource}"
      EffectiveResources.authorized?(self, :destroy, resource)

      if resource.destroy
        flash[:success] = flash_success(resource, :delete)
      else
        flash[:danger] = flash_danger(resource, :delete)
      end

      if request.referer.present? && !request.referer.include?(effective_resource.show_path)
        redirect_to(request.referer)
      else
        redirect_to(resource_index_path)
      end
    end

    def member_post_action(action)
      raise 'expected post, patch or put http action' unless (request.post? || request.patch? || request.put?)
      raise "expected @#{resource_name} to respond to #{action}!" unless resource.respond_to?("#{action}!")

      begin
        resource.public_send("#{action}!") || raise("failed to #{action} #{resource}")

        flash[:success] = flash_success(resource, action)
        redirect_back(fallback_location: resource_redirect_path)
      rescue => e
        flash.now[:danger] = flash_danger(resource, action, e: e)

        referer = request.referer.to_s

        if resource_edit_path && referer.end_with?(resource_edit_path)
          @page_title ||= "Edit #{resource}"
          render :edit
        elsif resource_new_path && referer.end_with?(resource_new_path)
          @page_title ||= "New #{resource_name.titleize}"
          render :new
        elsif resource_show_path && referer.end_with?(resource_show_path)
          @page_title ||= resource_name.titleize
          render :show
        else
          @page_title ||= resource.to_s
          flash[:danger] = flash.now[:danger]

          if referer.present? && (Rails.application.routes.recognize_path(URI(referer).path) rescue false)
            redirect_back(fallback_location: resource_redirect_path)
          else
            redirect_to(resource_redirect_path)
          end
        end
      end
    end

    def collection_post_action(action)
      action = action.to_s.gsub('bulk_', '').to_sym

      raise 'expected post, patch or put http action' unless (request.post? || request.patch? || request.put?)
      raise "expected #{resource_name} to respond to #{action}!" if resources.to_a.present? && !resources.first.respond_to?("#{action}!")

      successes = 0

      resource_klass.transaction do
        successes = resources.select do |resource|
          begin
            resource.public_send("#{action}!") if EffectiveResources.authorized?(self, action, resource)
          rescue => e
            false
          end
        end.length
      end

      render json: { status: 200, message: "Successfully #{action_verb(action)} #{successes} / #{resources.length} selected #{resource_plural_name}" }
    end

    protected

    def resource_redirect_path
      case params[:commit].to_s
      when 'Save'
        [resource_edit_path, resource_show_path, resource_index_path].compact.first
      when 'Save and Add New'
        [resource_new_path, resource_index_path].compact.first
      when 'Save and Continue'
        resource_index_path
      when 'Save and Return'
        request.referer.present? ? request.referer : resource_index_path
      else
        [resource_edit_path, resource_show_path, resource_index_path].compact.first
      end
    end

    def resource_index_path
      send(effective_resource.index_path) if effective_resource.index_path(check: true)
    end

    def resource_new_path
      send(effective_resource.new_path) if effective_resource.new_path(check: true)
    end

    def resource_edit_path
      send(effective_resource.edit_path, resource) if effective_resource.edit_path(check: true)
    end

    def resource_show_path
      send(effective_resource.show_path, resource) if effective_resource.show_path(check: true)
    end

    def resource_destroy_path
      send(effective_resource.destroy_path, resource) if effective_resource.destroy_path(check: true)
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

    private

    def effective_resource
      @_effective_resource ||= Effective::Resource.new(controller_path)
    end

    def resource_name # 'thing'
      effective_resource.name
    end

    def resource_klass # Thing
      effective_resource.klass
    end

    def resource_human_name
      effective_resource.human_name
    end

    def resource_plural_name # 'things'
      effective_resource.plural_name
    end

    def action_verb(action)
      (action.to_s + (action.to_s.end_with?('e') ? 'd' : 'ed'))
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
          effective_resource.klass.all
        else
          raise "expected resource_scope method to return an ActiveRecord::Relation or Hash"
        end

        unless relation.kind_of?(ActiveRecord::Relation)
          raise("unable to build resource_scope for #{effective_resource.klass || 'unknown klass'}.")
        end

        relation
      )
    end

    def resource_datatable_attributes
      resource_scope.where_values_hash.symbolize_keys
    end

    def resource_datatable_class # ThingsDatatable
      effective_resource.datatable_klass
    end

    def resource_params_method_name
      ["#{resource_name}_params", "#{resource_plural_name}_params", 'permitted_params'].find { |name| respond_to?(name, true) } || 'params'
    end

  end
end
