module Effective
  module CrudController
    extend ActiveSupport::Concern

    include Effective::CrudController::Actions
    include Effective::CrudController::Submits

    included do
      define_actions_from_routes
      define_callbacks :resource_render, :resource_save, :resource_error
    end

    module ClassMethods
      # Automatically respond to any action defined via the routes file
      def define_actions_from_routes
        (effective_resource.member_actions - effective_resource.crud_actions).each do |action|
          define_method(action) { member_action(action) }
        end

        (effective_resource.collection_actions - effective_resource.crud_actions).each do |action|
          define_method(action) { collecton_action(action) }
        end
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
      # Takes precidence over any 'on' dsl commands
      #
      # Effective::Resource will populate this with all crud actions
      # And you can control the details with this DSL:
      #
      # submit :approve, 'Save and Approve', unless: -> { approved? }, redirect: :show
      #
      # submit :toggle, 'Blacklist', if: -> { sync? }, class: 'btn btn-primary'
      # submit :toggle, 'Whitelist', if: -> { !sync? }, class: 'btn btn-primary'
      # submit :save, 'Save', success: -> { "#{self} was saved okay!" }

      def submit(action, label = nil, args = {})
        _insert_submit(action, label, args)
      end

      # This controls the resource buttons section of the page
      # Takes precidence over any on commands
      #
      # Effective::Resource will populate this with all member_actions
      #
      # button :approve, 'Approve', unless: -> { approved? }, redirect: :show
      # button :decline, false
      def button(action, label = nil, args = {})
        _insert_button(action, label, args)
      end

      # This is a way of defining the redirect, flash etc of any action without tweaking defaults
      # submit and buttons options will be merged ontop of these

      def on(action, args = {})
        _insert_on(action, args)
      end

      # page_title 'My Title', only: [:new]
      def page_title(label = nil, opts = {}, &block)
        opts = label if label.kind_of?(Hash)
        raise 'expected a label or block' unless (label || block_given?)

        instance_exec do
          before_action(opts) { @page_title ||= (block_given? ? instance_exec(&block) : label).to_s }
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
          before_action(opts) { @_effective_resource_scope ||= instance_exec(&(block_given? ? block : obj)) }
        end
      end

      private

      def effective_resource
        @_effective_resource ||= Effective::Resource.new(controller_path)
      end

    end

    protected

    # This calls the appropriate member action, probably save!, on the resource.
    def save_resource(resource, action = :save, to_assign = {}, &block)
      raise "expected @#{resource_name} to respond to #{action}!" unless resource.respond_to?("#{action}!")

      resource.current_user ||= current_user if resource.respond_to?(:current_user=)

      ActiveRecord::Base.transaction do
        begin
          resource.assign_attributes(to_assign) if to_assign.respond_to?(:permitted?) && to_assign.permitted?

          if resource.public_send("#{action}!") == false
            raise("failed to #{action} #{resource}")
          end

          yield if block_given?

          run_callbacks(:resource_save)
          return true
        rescue => e
          Rails.logger.info "Failed to #{action}: #{e.message}" if Rails.env.development?

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

    def resource_plural_name # 'things'
      effective_resource.plural_name
    end

    # Based on the incoming params[:commit] or passed action
    # Merges any ons
    def commit_action(action = nil)
      config = (['create', 'update'].include?(params[:action]) ? self.class.submits : self.class.buttons)

      commit = if action.present?
        config[action.to_s] || config.find { |_, v| v[:action] == action }.try(:last) || { action: action }
      else
        config[params[:commit].to_s] || config.find { |_, v| v[:action] == :save } || { action: :save }
      end

      commit.reverse_merge!(self.class.ons[commit[:action]]) if self.class.ons[commit[:action]]

      commit
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
