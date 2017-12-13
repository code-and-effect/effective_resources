module Effective
  module CrudController
    extend ActiveSupport::Concern

    included do
      class << self
        def member_actions
          @_effective_member_actions ||= {}
        end

        def _default_member_actions
          {
            'Save' => { action: :save, data: { disable_with: 'Saving...' }},
            'Continue' => { action: :save, data: { disable_with: 'Saving...' }},
            'Add New' => { action: :save, data: { disable_with: 'Saving...' }}
          }
        end
      end

      define_callbacks :resource_render, :resource_save, :resource_error
    end

    module ClassMethods

      # https://github.com/rails/rails/blob/v5.1.4/actionpack/lib/abstract_controller/callbacks.rb
      def before_render(*names, &blk)
        _insert_callbacks(names, blk) { |name, options| set_callback(:resource_render, :before, name, options) }
      end

      def after_save(*names, &blk)
        _insert_callbacks(names, blk) { |name, options| set_callback(:resource_save, :after, name, options) }
      end

      def after_error(*names, &blk)
        _insert_callbacks(names, blk) { |name, options| set_callback(:resource_error, :after, name, options) }
      end

      # Add the following to your controller for a simple member action
      # member_action :print
      #
      # Add to your permissions:  can :print, Thing
      #
      # If you want to POST and do an action based on this:
      # Make sure your model responds to approve!
      # member_action :approve
      # If you want it to automatically show up in your forms
      # member_action :approve, 'Save and Approve', if: -> { approved? }
      # member_action :approve, 'Save and Approve', unless: -> { !approved? }, redirect: :show

      def member_action(action, commit = nil, args = {})
        if commit.present?
          raise 'expected args to be a Hash or false' unless args.kind_of?(Hash) || args == false

          if args == false
            member_actions.delete(commit); return
          end

          if args.key?(:if) && args[:if].respond_to?(:call) == false
            raise "expected if: to be callable. Try member_action :approve, 'Save and Approve', if: -> { submitted? }"
          end

          if args.key?(:unless) && args[:unless].respond_to?(:call) == false
            raise "expected unless: to be callable. Try member_action :approve, 'Save and Approve', unless: -> { declined? }"
          end

          redirect = args.delete(:redirect_to) || args.delete(:redirect) # Remove redirect_to keyword. use redirect.

          member_actions[commit] = (args || {}).merge(action: action, redirect: redirect)
        end

        define_method(action) do
          self.resource ||= resource_scope.find(params[:id])

          EffectiveResources.authorize!(self, action, resource)

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

          EffectiveResources.authorize!(self, action, resource_klass)

          @page_title ||= "#{action.to_s.titleize} #{resource_plural_name.titleize}"

          collection_post_action(action) unless request.get?
        end
      end

      # Applies the default actions
      def default_actions(args = {})
        default_member_actions.each { |k, v| member_actions[k] = (args || {}).merge(v) }
      end

      # page_title 'My Title', only: [:new]
      def page_title(label = nil, opts = {}, &block)
        raise 'expected a label or block' unless (label || block_given?)

        instance_exec do
          before_action(opts) do
            @page_title ||= (block_given? ? instance_exec(&block) : label)
          end
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
      EffectiveDatatables.authorize!(self, :index, resource_klass)

      self.resources ||= resource_scope.all

      if resource_datatable_class
        @datatable ||= resource_datatable_class.new(self, resource_datatable_attributes)
      end

      run_callbacks(:resource_render)
    end

    def new
      self.resource ||= resource_scope.new

      self.resource.assign_attributes(
        params.to_unsafe_h.except(:controller, :action).select { |k, v| resource.respond_to?("#{k}=") }
      )

      @page_title ||= "New #{resource_name.titleize}"
      EffectiveResources.authorize!(self, :new, resource)

      run_callbacks(:resource_render)
    end

    def create
      self.resource ||= resource_scope.new

      @page_title ||= "New #{resource_name.titleize}"
      EffectiveResources.authorize!(self, :create, resource)

      action = commit_action[:action]
      EffectiveResources.authorize!(self, action, resource) unless action == :save

      resource.assign_attributes(send(resource_params_method_name))
      resource.created_by ||= current_user if resource.respond_to?(:created_by=)

      if save_resource(resource, action)
        flash[:success] ||= flash_success(resource, action)
        redirect_to(resource_redirect_path)
      else
        flash.now[:danger] ||= flash_danger(resource, action)
        render :new
      end
    end

    def show
      self.resource ||= resource_scope.find(params[:id])

      @page_title ||= resource.to_s
      EffectiveResources.authorize!(self, :show, resource)

      run_callbacks(:resource_render)
    end

    def edit
      self.resource ||= resource_scope.find(params[:id])

      @page_title ||= "Edit #{resource}"
      EffectiveResources.authorize!(self, :edit, resource)

      run_callbacks(:resource_render)
    end

    def update
      self.resource ||= resource_scope.find(params[:id])

      @page_title = "Edit #{resource}"
      EffectiveResources.authorize!(self, :update, resource)

      action = commit_action[:action]
      EffectiveResources.authorize!(self, action, resource) unless action == :save

      resource.assign_attributes(send(resource_params_method_name))

      if save_resource(resource, action)
        flash[:success] ||= flash_success(resource, action)
        redirect_to(resource_redirect_path)
      else
        flash.now[:danger] ||= flash_danger(resource, action)
        render :edit
      end
    end

    def destroy
      self.resource = resource_scope.find(params[:id])

      @page_title ||= "Destroy #{resource}"
      EffectiveResources.authorize!(self, :destroy, resource)

      if resource.destroy
        flash[:success] ||= flash_success(resource, :delete)
      else
        flash[:danger] ||= flash_danger(resource, :delete)
      end

      # Make sure we didn't come from a member action that we no longer exist at
      if referer_redirect_path && !request.referer.to_s.include?("/#{resource.to_param}/")
        redirect_to(referer_redirect_path)
      else
        redirect_to(resource_redirect_path)
      end
    end

    # No attributes are assigned or saved. We purely call action! on the resource.
    def member_post_action(action)
      raise 'expected post, patch or put http action' unless (request.post? || request.patch? || request.put?)

      if save_resource(resource, action)
        flash[:success] ||= flash_success(resource, action)
        redirect_to(referer_redirect_path || resource_redirect_path)
      else
        flash.now[:danger] ||= flash_danger(resource, action)

        if resource_edit_path && (referer_redirect_path || '').end_with?(resource_edit_path)
          @page_title ||= "Edit #{resource}"
          render :edit
        elsif resource_new_path && (referer_redirect_path || '').end_with?(resource_new_path)
          @page_title ||= "New #{resource_name.titleize}"
          render :new
        elsif resource_show_path && (referer_redirect_path || '').end_with?(resource_show_path)
          @page_title ||= resource_name.titleize
          render :show
        else
          @page_title ||= resource.to_s
          flash[:danger] = flash.now[:danger]
          redirect_to(referer_redirect_path || resource_redirect_path)
        end
      end
    end

    # No attributes are assigned or saved. We purely call action! on the resource
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



 # The block must implement a comparison between a and b and return an integer
 # less than 0 when b follows a, 0 when a and b are equivalent, or an integer greater than 0 when a follows b.

    # Here we look at all available (class level) member actions, see which ones apply to the current resource
    # This feeds into the helper simple_form_submit(f)
    # Returns a Hash of {'Save': {data-disable-with: 'Saving...'}, 'Approve': {data-disable-with: 'Approve'}}
    def member_actions_for(obj)
      actions = (self.class.member_actions.presence || self.class._default_member_actions)

      actions.select do |commit, args|
        args[:class] = args[:class].to_s

        (args.key?(:if) ? obj.instance_exec(&args[:if]) : true) &&
        (args.key?(:unless) ? !obj.instance_exec(&args[:unless]) : true)
      end.sort do |(commit_x, x), (commit_y, y)|
        # Sort to front
        primary = (y[:class].include?('primary') ? 1 : 0) - (x[:class].include?('primary') ? 1 : 0)
        primary = nil if primary == 0

        # Sort to back
        danger = (x[:class].include?('danger') ? 1 : 0) - (y[:class].include?('danger') ? 1 : 0)
        danger = nil if danger == 0

        primary || danger || actions.keys.index(commit_x) <=> actions.keys.index(commit_y)
      end.inject({}) do |h, (commit, args)|
        h[commit] = args.except(:action, :if, :unless, :redirect); h
      end
    end

    protected

    # This calls the appropriate member action, probably save!, on the resource.
    def save_resource(resource, action = :save)
      raise "expected @#{resource_name} to respond to #{action}!" unless resource.respond_to?("#{action}!")

      resource.current_user ||= current_user if resource.respond_to?(:current_user=)

      resource_klass.transaction do
        begin
          resource.public_send("#{action}!") || raise("failed to #{action} #{resource}")
          run_callbacks(:resource_save)
          return true
        rescue => e
          flash.delete(:success)
          flash.now[:danger] = flash_danger(resource, action, e: e)
          raise ActiveRecord::Rollback
        end
      end

      run_callbacks(:resource_error)
      false
    end

    def resource_redirect_path
      return instance_exec(&commit_action[:redirect]) if commit_action[:redirect].respond_to?(:call)

      commit_action_redirect = case commit_action[:redirect]
        when :index ; resource_index_path
        when :edit  ; resource_edit_path
        when :show  ; resource_show_path
        when :back  ; referer_redirect_path
        when nil    ; nil
        else        ; resource_member_action_path(commit_action[:action])
      end

      return commit_action_redirect if commit_action_redirect.present?

      case params[:commit].to_s
      when 'Save'
        [resource_edit_path, resource_show_path, resource_index_path].compact.first
      when 'Save and Add New', 'Add New'
        [resource_new_path, resource_index_path].compact.first
      when 'Continue', 'Save and Continue'
        resource_index_path
      else
        [referer_redirect_path, resource_index_path].compact.first
      end.presence || root_path
    end

    def referer_redirect_path
      if request.referer.present? && (Rails.application.routes.recognize_path(URI(request.referer.to_s).path) rescue false)
        request.referer.to_s
      end
    end

    def resource_index_path
      effective_resource.action_path(:index)
    end

    def resource_new_path
      effective_resource.action_path(:new)
    end

    def resource_edit_path
      effective_resource.action_path(:edit, resource)
    end

    def resource_show_path
      effective_resource.action_path(:show, resource)
    end

    def resource_destroy_path
      effective_resource.action_path(:destroy, resource)
    end

    def resource_member_action_path(action)
      effective_resource.action_path(action.to_sym, resource)
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

    def commit_action
      self.class.member_actions[params[:commit].to_s] || { action: :save }
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
