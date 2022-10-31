# frozen_string_literal: true

module EffectiveResourcesPrivateHelper
  REPLACE_PAGE_ACTIONS = {'update' => :edit, 'create' => :new}
  BLACKLIST = [:default, :only, :except, :if, :unless, :redirect, :success, :danger, :klass]

  def permitted_resource_actions(resource, actions)
    page_action = REPLACE_PAGE_ACTIONS[params[:action]] || params[:action].try(:to_sym) || :save
    executor = Effective::ResourceExec.new(self, resource)

    actions.each_with_object({}) do |(commit, args), h|
      action = (args[:action] == :save ? (resource.new_record? ? :create : :update) : args[:action])

      permitted = (args.key?(:only) ? args[:only].include?(page_action) : true) &&
        (args.key?(:except) ? !args[:except].include?(page_action) : true) &&
        (args.key?(:if) ? executor.instance_exec(&args[:if]) : true) &&
        (args.key?(:unless) ? !executor.instance_exec(&args[:unless]) : true) &&
        EffectiveResources.authorized?(controller, action, resource)

      next unless permitted

      opts = args.except(:default, :only, :except, :if, :unless, :redirect, :success, :danger, :klass)
      resource_to_s = resource.to_s.presence || resource.class.name.underscore

      # Transform data: { ... } hash into 'data-' keys
      if opts.key?(:data)
        opts.delete(:data).each { |k, v| opts["data-#{k}"] ||= v }
      end

      if opts.key?(:path)
        opts[:href] = opts.delete(:path)
      end

      if opts.key?(:url)
        opts[:href] = opts.delete(:url)
      end

      # Replace resource name in any token strings
      if opts.key?('data-confirm') && opts['data-confirm'].to_s.include?('@resource')
        opts['data-confirm'] = opts['data-confirm'].gsub('@resource', resource_to_s)
      end

      # Assign class
      opts[:class] ||= (
        if opts['data-method'].to_s == 'delete'
          'btn btn-danger'
        elsif h.length == 0
          'btn btn-primary'
        elsif defined?(EffectiveBootstrap)
          'btn btn-secondary'
        else
          'btn btn-default'
        end
      )

      # Assign title
      opts[:title] ||= case opts[:action]
        when :save then commit
        when :edit then "Edit #{resource_to_s}"
        when :show then "#{resource_to_s}"
        when :destroy then "Delete #{resource_to_s}"
        when :index then "All #{resource.class.name.gsub('::', ' ').underscore.gsub('_', ' ').titleize.pluralize}"
        else "#{opts[:action].to_s.titleize} #{resource_to_s}"
      end

      h[commit] = opts
    end
  end

  def find_effective_resource(resource = nil)
    @_effective_resource ||= (controller.respond_to?(:effective_resource) ? controller.effective_resource : Effective::Resource.new(controller_path))

    # We might be calling this on a sub resource of the same page.
    if resource.present? && @_effective_resource.present?
      resource = Array(resource).first

      if resource.kind_of?(ActiveRecord::Base) && resource.class != @_effective_resource.klass
        return Effective::Resource.new(resource, namespace: @_effective_resource.namespace)
      end
    end

    @_effective_resource
  end

end
