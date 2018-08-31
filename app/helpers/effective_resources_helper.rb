module EffectiveResourcesHelper

  # effective_bootstrap
  def effective_submit(form, options = {}, &block)
    actions = (controller.respond_to?(:effective_resource) ? controller.class : find_effective_resource).submits
    actions = permitted_resource_actions(form.object, actions)

    submits = actions.map { |name, opts| form.save(name, opts.except(:action, :title, 'data-method', 'data-confirm')) }.join.html_safe

    form.submit('', options) do
      (block_given? ? capture(&block) : ''.html_safe) + submits
    end
  end

  # effective_form_inputs
  def simple_form_submit(form, options = {}, &block)
    actions = (controller.respond_to?(:effective_resource) ? controller.class : find_effective_resource).submits
    actions = permitted_resource_actions(form.object, actions)

    submits = actions.map { |name, opts| form.button(:submit, name, opts.except(:action, :title, 'data-method', 'data-confirm')) }.join('&nbsp;').html_safe

    # I think this is a bug. I can't override default button class when passing my own class: variable. it merges them.
    if (btn_class = SimpleForm.button_class).present?
      submits = submits.map { |submit| submit.sub(btn_class, '') }
    end

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
  # resource is an Effective::Resource
  # instance is an ActiveRecord thing, an Array of ActiveRecord things, or nil
  # Atts are everything else. Interesting ones include:

  # partial: :dropleft|:glyphicons|string
  # locals: {} render locals
  # you can also pass all action names and true/false such as edit: true, show: false
  def render_resource_actions(resource, atts = {}, &block)
    raise 'expected first argument to be an ActiveRecord::Base object or Array of objects' unless resource.kind_of?(ActiveRecord::Base) || resource.kind_of?(Class) || resource.kind_of?(Array)
    raise 'expected attributes to be a Hash' unless atts.kind_of?(Hash)

    locals = atts.delete(:locals) || {}
    partial = atts.delete(:partial)
    spacer_template = locals.delete(:spacer_template)

    effective_resource = (atts.delete(:effective_resource) || find_effective_resource)
    actions = atts.delete(:actions) || effective_resource.resource_actions
    namespace = atts.delete(:namespace) || (effective_resource.namespace.to_sym if effective_resource.namespace)

    # Filter Actions
    action_keys = actions.map { |_, v| v[:action] }
    raise "unknown action for #{effective_resource.name}: #{(atts.keys - action_keys).join(' ')}." if (atts.keys - action_keys).present?
    actions = actions.select { |_, v| atts[v[:action]].respond_to?(:call) ? instance_exec(&atts[v[:action]]) : (atts[v[:action]] != false) }

    # Select Partial
    partial = ['effective/resource/actions', partial.to_s].join('_') if partial.kind_of?(Symbol)
    partial = (partial.presence || 'effective/resource/actions') + '.html'

    # Assign Locals
    locals = { resource: resource, effective_resource: effective_resource, namespace: namespace, actions: actions }.compact.merge(locals)

    # Render
    if resource.kind_of?(Array)
      locals[:format_block] = block if block_given?
      render(partial: partial, collection: resource, as: :resource, locals: locals.except(:resource), spacer_template: spacer_template)
    elsif block_given?
      render(partial, locals) { yield }
    else
      render(partial, locals)
    end
  end

  # When called from /admin/things/new.html.haml this will render 'admin/things/form', or 'things/form', or 'thing/form'
  def render_resource_form(resource, atts = {})
    raise 'expected first argument to be an ActiveRecord::Base object' unless resource.kind_of?(ActiveRecord::Base)
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
