# frozen_string_literal: true

module EffectiveResourcesHelper

  # effective_bootstrap
  def effective_submit(form, options = {}, &block)
    actions = (controller.respond_to?(:effective_resource) ? controller.class : find_effective_resource).submits
    actions = actions.select { |k, v| v[:default] != true } if options.delete(:defaults) == false
    actions = permitted_resource_actions(form.object, actions)

    submits = actions.map { |name, opts| form.save(name, opts.except(:action, :title, 'data-method') ) }.join.html_safe

    form.submit('', options) do
      (block_given? ? capture(&block) : ''.html_safe) + submits
    end
  end

  # effective_form_inputs
  def simple_form_submit(form, options = {}, &block)
    actions = (controller.respond_to?(:effective_resource) ? controller.class : find_effective_resource).submits
    actions = permitted_resource_actions(form.object, actions)

    submits = actions.map { |name, opts| form.button(:submit, name, opts.except(:action, :title, 'data-method')) }

    # I think this is a bug. I can't override default button class when passing my own class: variable. it merges them.
    if (btn_class = SimpleForm.button_class).present?
      submits = submits.map { |submit| submit.sub(btn_class, '') }
    end

    submits = submits.join('&nbsp;').html_safe

    wrapper_options = { class: 'form-actions' }.merge(options.delete(:wrapper_html) || {})

    content_tag(:div, wrapper_options) do
      (block_given? ? capture(&block) : ''.html_safe) + submits
    end
  end

  def render_resource_buttons(resource, atts = {}, &block)
    effective_resource = find_effective_resource
    actions = (controller.respond_to?(:effective_resource) ? controller.class : effective_resource).buttons

    actions = if resource.kind_of?(Class)
      actions.select { |_, v| effective_resource.collection_get_actions.include?(v[:action]) }
    elsif resource.respond_to?(:persisted?) && resource.persisted?
      actions.select { |_, v| effective_resource.member_actions.include?(v[:action]) }
    else
      {}
    end

    render_resource_actions(resource, atts.merge(actions: actions), &block)
  end

  # Renders the effective/resource view partial for this resource
  # resource is an ActiveRecord thing, an Array of ActiveRecord things, or nil
  # Atts are everything else. Interesting ones include:

  # partial: :dropleft|:glyphicons|string
  # locals: {} render locals
  # you can also pass all action names and true/false such as edit: true, show: false
  def render_resource_actions(resource, atts = {}, &block)
    unless resource.kind_of?(ActiveRecord::Base) || resource.kind_of?(Class) || resource.kind_of?(Array) || resource.class.ancestors.include?(ActiveModel::Model)
      raise 'expected first argument to be an ActiveRecord::Base object or Array of objects'
    end

    raise 'expected attributes to be a Hash' unless atts.kind_of?(Hash)

    btn_class = atts[:btn_class]
    effective_resource = atts[:effective_resource]
    namespace = atts[:controller_namespace] || atts[:namespace]
    locals = atts[:locals] || {}
    partial = atts[:partial]
    spacer_template = locals[:spacer_template]

    effective_resource ||= find_effective_resource(resource)
    namespace ||= (effective_resource.namespace.to_sym if effective_resource.namespace)

    # Assign actions
    # We filter out any actions passed to us that aren't supported
    actions = if atts.key?(:actions)
      {}.tap do |actions|
        atts[:actions].each do |commit, opts|
          actions[commit] = opts if (effective_resource.actions.include?(opts[:action]) || opts[:path]).present?
        end
      end
    else
      (resource.kind_of?(Class) ? effective_resource.resource_klass_actions : effective_resource.resource_actions)
    end

    # Consider only, except, false and proc false
    only = Array(atts[:only]) if atts[:only].present?
    except = Array(atts[:except]) if atts[:except].present?

    actions.select! do |_, opts|
      action = opts[:action]

      if only.present? && !only.include?(action)
        false
      elsif except.present? && except.include?(action)
        false
      elsif atts[action].respond_to?(:call)
        Effective::ResourceExec.new(self, resource).instance_exec(&atts[action])
      else
        atts[action] != false
      end
    end

    # Select Partial
    partial = if partial.kind_of?(Symbol)
      "effective/resource/actions_#{partial}.html"
    else
      "#{partial.presence || 'effective/resource/actions'}.html"
    end

    # Assign Locals
    locals = {
      resource: resource,
      effective_resource: effective_resource,
      format_block: (block if block_given?),
      namespace: namespace,
      actions: actions,
      btn_class: (btn_class || '')
    }.compact.merge(locals)

    if resource.kind_of?(Array)
      render(partial: partial, collection: resource, as: :resource, locals: locals.except(:resource), spacer_template: spacer_template)
    else
      render(partial, locals)
    end
  end

  # When called from /admin/things/new.html.haml this will render 'admin/things/form', or 'things/form', or 'thing/form'
  def render_resource_form(resource, atts = {})
    unless resource.kind_of?(ActiveRecord::Base) || resource.class.ancestors.include?(ActiveModel::Model)
      raise 'expected first argument to be an ActiveRecord or ActiveModel object'
    end

    raise 'expected attributes to be a Hash' unless atts.kind_of?(Hash)

    effective_resource = (atts.delete(:effective_resource) || find_effective_resource)

    action = atts.delete(:action)
    atts = { :namespace => (effective_resource.namespace.to_sym if effective_resource.namespace), effective_resource.name.to_sym => resource }.compact.merge(atts)

    if lookup_context.template_exists?("form_#{action}", controller._prefixes, :partial)
      render "form_#{action}", atts
    elsif lookup_context.template_exists?('form', controller._prefixes, :partial)
      render 'form', atts
    elsif lookup_context.template_exists?('form', effective_resource.plural_name, :partial)
      render "#{effective_resource.plural_name}/form", atts
    elsif lookup_context.template_exists?('form', effective_resource.name, :partial)
      render "#{effective_resource.name}/form", atts
    else
      render 'form', atts  # Will raise the regular error
    end
  end

  # Similar to render_resource_form
  def render_resource_partial(resource, atts = {})
    unless resource.kind_of?(ActiveRecord::Base) || resource.class.ancestors.include?(ActiveModel::Model)
      raise 'expected first argument to be an ActiveRecord or ActiveModel object'
    end

    raise 'expected attributes to be a Hash' unless atts.kind_of?(Hash)

    effective_resource = (atts.delete(:effective_resource) || find_effective_resource)

    action = atts.delete(:action)
    atts = { :namespace => (effective_resource.namespace.to_sym if effective_resource.namespace), effective_resource.name.to_sym => resource }.compact.merge(atts)

    if lookup_context.template_exists?(effective_resource.name, controller._prefixes, :partial)
      render(effective_resource.name, atts)
    elsif lookup_context.template_exists?(effective_resource.name, [effective_resource.plural_name], :partial)
      render(effective_resource.plural_name + '/' + effective_resource.name, atts)
    elsif lookup_context.template_exists?(effective_resource.name, [effective_resource.name], :partial)
      render(effective_resource.name + '/' + effective_resource.name, atts)
    else
      render(resource, atts)  # Will raise the regular error
    end
  end

  # Tableize attributes
  # This is used by effective_orders, effective_logging, effective_trash and effective_mergery
  def tableize_hash(obj, table: 'table', th: true, sub_table: 'table', sub_th: true, flatten: true)
    case obj
    when Hash
      if flatten && obj[:attributes].kind_of?(Hash)
        obj = obj[:attributes].merge(obj.except(:attributes))
      end

      content_tag(:table, class: table.presence) do
        content_tag(:tbody) do
          obj.map do |key, value|
            content_tag(:tr, class: key.to_param) do
              content_tag((th == true ? :th : :td), key) +
              content_tag(:td) { tableize_hash(value, table: sub_table, th: sub_th, sub_table: sub_table, sub_th: sub_th, flatten: flatten) }
            end
          end.join.html_safe
        end
      end
    when Array
      obj.map { |value| tableize_hash(value, table: sub_table, th: sub_th, sub_table: sub_table, sub_th: sub_th, flatten: flatten) }.join('<br>')
    when Symbol
      ":#{obj}"
    when NilClass
      '-'
    else
      obj.to_s.presence || '""'
    end.html_safe
  end

  def format_resource_value(value)
    @format_resource_tags ||= ActionView::Base.sanitized_allowed_tags.to_a + ['table', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th']
    @format_resource_atts ||= ActionView::Base.sanitized_allowed_attributes.to_a + ['colspan', 'rowspan']

    simple_format(sanitize(value.to_s, tags: @format_resource_tags, attributes: @format_resource_atts), {}, sanitize: false)
  end

end
