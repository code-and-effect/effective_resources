module EffectiveResourcesPrivateHelper
  REPLACE_PAGE_ACTIONS = {'update' => :edit, 'create' => :new}

  def permitted_resource_actions(resource, actions, effective_resource = nil)
    effective_resource ||= find_effective_resource

    page_action = REPLACE_PAGE_ACTIONS[params[:action]] || params[:action]&.to_sym || :save

    actions.select do |commit, args|
      action = (args[:action] == :save ? (resource.new_record? ? :create : :update) : args[:action])

      (args.key?(:only) ? args[:only].include?(page_action) : true) &&
      (args.key?(:except) ? !args[:except].include?(page_action) : true) &&
      (args.key?(:if) ? controller.instance_exec(&args[:if]) : true) &&
      (args.key?(:unless) ? !controller.instance_exec(&args[:unless]) : true) &&
      EffectiveResources.authorized?(controller, action, resource)
    end.transform_values.with_index do |opts, index|
      action = opts[:action]

      # Transform data: { ... } hash into 'data-' keys
      data.each { |k, v| opts["data-#{k}"] ||= v } if (data = opts.delete(:data))

      # Assign data method and confirm
      if effective_resource.member_post_actions.include?(action)
        opts['data-method'] ||= :post
        opts['data-confirm'] ||= "Really #{action} @resource?"
      elsif effective_resource.member_delete_actions.include?(action)
        opts['data-method'] ||= :delete
        opts['data-confirm'] ||= "Really #{action == :destroy ? 'delete' : action.to_s.titleize} @resource?"
      end

      # Assign class
      opts[:class] ||= (
        if opts['data-method'] == :delete
          'btn btn-danger'
        elsif index == 0
          'btn btn-primary'
        elsif defined?(EffectiveBootstrap)
          'btn btn-secondary'
        else
          'btn btn-default'
        end
      )

      # Assign title
      unless action == :save
        opts[:title] ||= case action
          when :edit then "Edit #{resource}"
          when :show then "#{resource}"
          when :destroy then "Delete #{resource}"
          when :index then "All #{effective_resource.human_plural_name.titleize}"
          else "#{action.to_s.titleize} #{resource}"
        end
      end

      # Replace resource name in any token strings
      if opts['data-confirm']
        opts['data-confirm'].gsub!('@resource', (resource.to_s.presence || effective_resource.human_name))
      end

      opts.except(:default, :only, :except, :if, :unless, :redirect, :success, :danger)
    end
  end

  def find_effective_resource
    @_effective_resource ||= (controller.respond_to?(:effective_resource) ? controller.effective_resource : Effective::Resource.new(controller_path))
  end

end
