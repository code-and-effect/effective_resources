module Effective
  module CrudController
    extend ActiveSupport::Concern

    included do
      class << self
        def effective_resource
          @_effective_resource ||= Effective::Resource.new(controller_path)
        end

        def submits
          effective_resource.submits
        end
      end

      define_actions_from_routes
      define_callbacks :resource_render, :resource_save, :resource_error
    end

    module ClassMethods

      # Automatically respond to any action defined via the routes file
      def define_actions_from_routes
        resource = Effective::Resource.new(controller_path)
        resource.member_actions.each { |action| member_action(action) }
        resource.collection_actions.each { |action| collection_action(action) }
      end

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

      # This controls the form submit options of effective_submit
      # It also controls the redirect path for any actions
      #
      # Effective::Resource will populate this with all member_post_actions
      # And you can control the details with this DSL:
      #
      # submit :approve, 'Save and Approve', unless: -> { approved? }, redirect: :show
      #
      # submit :toggle, 'Blacklist', if: -> { sync? }, class: 'btn btn-primary'
      # submit :toggle, 'Whitelist', if: -> { !sync? }, class: 'btn btn-primary'
      # submit :save, 'Save', success: -> { "#{self} was saved okay!" }

      def submit(action, commit = nil, args = {})
        raise 'expected args to be a Hash or false' unless args.kind_of?(Hash) || args == false

        if commit == false
          submits.delete_if { |commit, args| args[:action] == action }; return
        end

        if args == false
          submits.delete(commit); return
        end

        if commit # Overwrite the default member action when given a custom commit
          submits.delete_if { |commit, args| args[:default] && args[:action] == action }
        end

        if args.key?(:if) && args[:if].respond_to?(:call) == false
          raise "expected if: to be callable. Try submit :approve, 'Save and Approve', if: -> { finished? }"
        end

        if args.key?(:unless) && args[:unless].respond_to?(:call) == false
          raise "expected unless: to be callable. Try submit :approve, 'Save and Approve', unless: -> { declined? }"
        end

        redirect = args.delete(:redirect_to) || args.delete(:redirect) # Remove redirect_to keyword. use redirect.
        args.merge!(action: action, redirect: redirect)

        (submits[commit] ||= {}).merge!(args)
      end

      # page_title 'My Title', only: [:new]
      def page_title(label = nil, opts = {}, &block)
        opts = label if label.kind_of?(Hash)
        raise 'expected a label or block' unless (label || block_given?)

        instance_exec do
          before_action(opts) do
            @page_title ||= (block_given? ? instance_exec(&block) : label).to_s
          end
        end
      end

      # resource_scope -> { current_user.things }
      # resource_scope -> { Thing.active.where(user: current_user) }
      # resource_scope do
      #   { user_id: current_user.id }
      # end
      # Nested controllers? sure
      # resource_scope -> { User.find(params[:user_id]).things }

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

      # Defines a function to handle a GET and POST request on this URL
      # Just add a member action to your routes, you shouldn't need to call this directly
      def member_action(action)
        define_method(action) do
          Rails.logger.info 'Processed by Effective::CrudController#member_action'

          self.resource ||= resource_scope.find(params[:id])

          EffectiveResources.authorize!(self, action, resource)

          @page_title ||= "#{action.to_s.titleize} #{resource}"

          request.get? ? run_callbacks(:resource_render) : member_post_action(action)
        end
      end

      # Defines a function to handle a GET and POST request on this URL
      # Handles bulk_ actions
      # Just add a member action to your routes, you shouldn't need to call this directly
      # You shouldn't need to call this directly
      def collection_action(action)
        define_method(action) do
          Rails.logger.info 'Processed by Effective::CrudController#collection_action'

          if params[:ids].present?
            self.resources ||= resource_scope.where(id: params[:ids])
          end

          if effective_resource.scope?(action)
            self.resources ||= resource_scope.public_send(action)
          end

          self.resources ||= resource_scope.all

          EffectiveResources.authorize!(self, action, resource_klass)

          @page_title ||= "#{action.to_s.titleize} #{resource_plural_name.titleize}"

          request.get? ? run_callbacks(:resource_render) : collection_post_action(action)
        end
      end
    end

    def index
      Rails.logger.info 'Processed by Effective::CrudController#index'

      @page_title ||= resource_plural_name.titleize
      EffectiveResources.authorize!(self, :index, resource_klass)

      self.resources ||= resource_scope.all

      if resource_datatable_class
        @datatable ||= resource_datatable_class.new(resource_datatable_attributes)
        @datatable.view = view_context
      end

      run_callbacks(:resource_render)
    end

    def new
      Rails.logger.info 'Processed by Effective::CrudController#new'

      self.resource ||= resource_scope.new

      self.resource.assign_attributes(
        params.to_unsafe_h.except(:controller, :action, :id).select { |k, v| resource.respond_to?("#{k}=") }
      )

      if params[:duplicate_id]
        duplicate = resource_scope.find(params[:duplicate_id])
        EffectiveResources.authorize!(self, :show, duplicate)

        self.resource = duplicate_resource(duplicate)
        raise "expected duplicate_resource to return an unsaved new #{resource_klass} resource" unless resource.kind_of?(resource_klass) && resource.new_record?

        if (message = flash[:success].to_s).present?
          flash.delete(:success)
          flash.now[:success] = "#{message.chomp('.')}. Adding another #{resource_name.titleize} based on previous."
        end
      end

      @page_title ||= "New #{resource_name.titleize}"
      EffectiveResources.authorize!(self, :new, resource)

      run_callbacks(:resource_render)
    end

    def create
      Rails.logger.info 'Processed by Effective::CrudController#create'

      self.resource ||= resource_scope.new

      @page_title ||= "New #{resource_name.titleize}"

      action = commit_action[:action]
      EffectiveResources.authorize!(self, action, resource) unless action == :save
      EffectiveResources.authorize!(self, :create, resource) if action == :save

      resource.created_by ||= current_user if resource.respond_to?(:created_by=)

      respond_to do |format|
        if save_resource(resource, action, send(resource_params_method_name))
          request.format = :html if specific_redirect_path?

          format.html do
            flash[:success] ||= resource_flash(:success, resource, action)
            redirect_to(resource_redirect_path)
          end

          format.js do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            reload_resource # create.js.erb
          end
        else
          flash.delete(:success)
          flash.now[:danger] ||= resource_flash(:danger, resource, action)

          run_callbacks(:resource_render)

          format.html { render :new }
          format.js {} # create.js.erb
        end
      end
    end

    def show
      Rails.logger.info 'Processed by Effective::CrudController#show'

      self.resource ||= resource_scope.find(params[:id])

      @page_title ||= resource.to_s
      EffectiveResources.authorize!(self, :show, resource)

      run_callbacks(:resource_render)
    end

    def edit
      Rails.logger.info 'Processed by Effective::CrudController#edit'

      self.resource ||= resource_scope.find(params[:id])

      @page_title ||= "Edit #{resource}"
      EffectiveResources.authorize!(self, :edit, resource)

      run_callbacks(:resource_render)
    end

    def update
      Rails.logger.info 'Processed by Effective::CrudController#update'

      self.resource ||= resource_scope.find(params[:id])

      @page_title = "Edit #{resource}"

      action = commit_action[:action]
      EffectiveResources.authorize!(self, action, resource) unless action == :save
      EffectiveResources.authorize!(self, :update, resource) if action == :save

      respond_to do |format|
        if save_resource(resource, action, send(resource_params_method_name))
          request.format = :html if specific_redirect_path?

          format.html do
            flash[:success] ||= resource_flash(:success, resource, action)
            redirect_to(resource_redirect_path)
          end

          format.js do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            reload_resource # update.js.erb
          end
        else
          flash.delete(:success)
          flash.now[:danger] ||= resource_flash(:danger, resource, action)

          run_callbacks(:resource_render)

          format.html { render :edit }
          format.js { } # update.js.erb
        end
      end
    end

    def destroy
      Rails.logger.info 'Processed by Effective::CrudController#destroy'

      self.resource = resource_scope.find(params[:id])

      action = :destroy
      @page_title ||= "Destroy #{resource}"
      EffectiveResources.authorize!(self, action, resource)

      respond_to do |format|
        if save_resource(resource, action)
          request.format = :html if specific_redirect_path?(action)

          format.html do
            flash[:success] ||= resource_flash(:success, resource, action)
            redirect_to(resource_redirect_path(action))
          end

          format.js do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            # destroy.js.erb
          end
        else
          flash.delete(:success)
          request.format = :html  # Don't run destroy.js.erb

          format.html do
            flash[:danger] = (flash.now[:danger].presence || resource_flash(:danger, resource, action))
            redirect_to(resource_redirect_path(action))
          end

        end
      end
    end

    def member_post_action(action)
      raise 'expected post, patch or put http action' unless (request.post? || request.patch? || request.put?)

      respond_to do |format|
        if save_resource(resource, action, (send(resource_params_method_name) rescue {}))
          request.format = :html if specific_redirect_path?(action)

          format.html do
            flash[:success] ||= resource_flash(:success, resource, action)
            redirect_to(resource_redirect_path(action))
          end

          format.js do
            flash.now[:success] ||= resource_flash(:success, resource, action)
            reload_resource
            render_member_action(action)
          end
        else
          flash.delete(:success)
          flash.now[:danger] ||= resource_flash(:danger, resource, action)

          run_callbacks(:resource_render)

          format.html do
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
              redirect_to(referer_redirect_path || resource_redirect_path(action))
            end
          end

          format.js { render_member_action(action) }
        end
      end
    end

    # Which member javascript view to render: #{action}.js or effective_resources member_action.js
    def render_member_action(action)
      view = lookup_context.template_exists?(action, _prefixes) ? action : :member_action
      render(view, locals: { action: action })
    end

    # No attributes are assigned or saved. We purely call action! on the resource
    def collection_post_action(action)
      action = action.to_s.gsub('bulk_', '').to_sym

      raise 'expected post, patch or put http action' unless (request.post? || request.patch? || request.put?)
      raise "expected #{resource_name} to respond to #{action}!" if resources.to_a.present? && !resources.first.respond_to?("#{action}!")

      successes = 0

      ActiveRecord::Base.transaction do
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

    # This calls the appropriate member action, probably save!, on the resource.
    def save_resource(resource, action = :save, to_assign = {}, &block)
      raise "expected @#{resource_name} to respond to #{action}!" unless resource.respond_to?("#{action}!")

      resource.current_user ||= current_user if resource.respond_to?(:current_user=)

      ActiveRecord::Base.transaction do
        begin
          resource.assign_attributes(to_assign) if to_assign.present?

          if resource.public_send("#{action}!") == false
            raise("failed to #{action} #{resource}")
          end

          yield if block_given?

          run_callbacks(:resource_save)
          return true
        rescue => e
          if resource.respond_to?(:restore_attributes) && resource.persisted?
            resource.restore_attributes(['status', 'state'])
          end

          flash.delete(:success)
          flash.now[:danger] = flash_danger(resource, action, e: e)
          raise ActiveRecord::Rollback
        end
      end

      run_callbacks(:resource_error)
      false
    end

    def reload_resource
      self.resource.reload if resource.respond_to?(:reload)
    end

    # Should return a new resource based on the passed one
    def duplicate_resource(resource)
      resource.dup
    end

    def resource_flash(status, resource, action)
      submit = commit_action(action)
      message = submit[status].respond_to?(:call) ? instance_exec(&submit[status]) : submit[status]
      return message if message.present?

      case status
      when :success then flash_success(resource, action)
      when :danger then flash_danger(resource, action)
      else
        raise "unknown resource flash status: #{status}"
      end
    end

    def resource_redirect_path(action = nil)
      submit = commit_action(action)
      redirect = submit[:redirect].respond_to?(:call) ? instance_exec(&submit[:redirect]) : submit[:redirect]

      commit_action_redirect = case redirect
        when :index     ; resource_index_path
        when :edit      ; resource_edit_path
        when :show      ; resource_show_path
        when :new       ; resource_new_path
        when :duplicate ; resource_duplicate_path
        when :back      ; referer_redirect_path
        when :save      ; [resource_edit_path, resource_show_path].compact.first
        when Symbol     ; resource_action_path(submit[:action])
        when String     ; redirect
        else            ; nil
      end

      return commit_action_redirect if commit_action_redirect.present?

      if action == :destroy
        return [referer_redirect_path, resource_index_path, root_path].compact.first
      end

      case params[:commit].to_s
      when 'Save'
        [resource_edit_path, resource_show_path, resource_index_path]
      when 'Save and Add New', 'Add New'
        [resource_new_path, resource_index_path]
      when 'Duplicate'
        [resource_duplicate_path, resource_index_path]
      when 'Continue', 'Save and Continue'
        [resource_index_path]
      else
        [referer_redirect_path, resource_edit_path, resource_show_path, resource_index_path]
      end.compact.first.presence || root_path
    end

    def referer_redirect_path
      url = request.referer.to_s

      return if (resource && resource.respond_to?(:destroyed?) && resource.destroyed? && url.include?("/#{resource.to_param}"))
      return if url.include?('duplicate_id=')
      return unless (Rails.application.routes.recognize_path(URI(url).path) rescue false)

      url
    end

    def resource_index_path
      effective_resource.action_path(:index)
    end

    def resource_new_path
      effective_resource.action_path(:new)
    end

    def resource_duplicate_path
      effective_resource.action_path(:new, duplicate_id: resource.id)
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

    def resource_action_path(action)
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

    # Based on the incoming params[:commit] or passed action
    def commit_action(action = nil)
      if action.present?
        self.class.submits[action.to_s] ||
        self.class.submits.find { |_, v| v[:action] == action }.try(:last) ||
        { action: action }
      else # Get the current commit
        self.class.submits[params[:commit].to_s] ||
        self.class.submits.find { |_, v| v[:action] == :save }.try(:last) ||
        { action: :save }
      end
    end

    def specific_redirect_path?(action = nil)
      submit = commit_action(action)
      (submit[:redirect].respond_to?(:call) ? instance_exec(&submit[:redirect]) : submit[:redirect]).present?
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
