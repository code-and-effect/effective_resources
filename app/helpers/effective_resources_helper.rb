module EffectiveResourcesHelper

  def effective_submit(form, options = {}, &block) # effective_bootstrap
    resource = (controller.class.respond_to?(:effective_resource) ? controller.class.effective_resource : Effective::Resource.new(controller_path))
    actions = resource.submits_for(form.object, controller: controller)
    buttons = actions.map { |name, opts| form.save(name, opts) }.join.html_safe

    form.submit('', options) do
      (block_given? ? capture(&block) : ''.html_safe) + buttons
    end
  end

  # effective_form_inputs
  def simple_form_submit(form, options = {}, &block)
    resource = (controller.class.respond_to?(:effective_resource) ? controller.class.effective_resource : Effective::Resource.new(controller_path))
    actions = resource.submits_for(form.object, controller: controller)

    buttons = actions.map { |action| form.button(:submit, *action) }

    # I think this is a bug. I can't override default button class when passing my own class: variable. it merges them.
    if defined?(SimpleForm) && (btn_class = SimpleForm.button_class).present?
      buttons = buttons.map { |button| button.sub(btn_class, '') }
    end

    wrapper_options = { class: 'form-actions' }.merge(options.delete(:wrapper_html) || {})

    content_tag(:div, wrapper_options) do
      (block_given? ? capture(&block) : ''.html_safe) + buttons.join('&nbsp;').html_safe
    end
  end

  def simple_form_save(form, label = 'Save', options = {}, &block)
    wrapper_options = { class: 'form-actions' }.merge(options.delete(:wrapper_html) || {})
    options = { class: 'btn btn-primary', data: { disable_with: 'Saving...'} }.merge(options)

    content_tag(:div, wrapper_options) do
      form.button(:submit, label, options) + (capture(&block) if block_given?)
    end
  end

  def render_resource_crud_actions(resource, instance = nil, atts = {}, &block)
    (atts = instance; instance = nil) if instance.kind_of?(Hash) && atts.blank?
    render_resource_actions(resource, instance, atts.merge(crud: true), &block)
  end

  # resource is an Effective::Resource
  # instance is an ActiveRecord thing
  # atts are crud: true|false, locals: {}, namespace:, partial:
  # anything else are actions, edit: true, show: false, destroy: false and member GET actions
  def render_resource_actions(resource, instance = nil, atts = {}, &block)
    (atts = instance; instance = nil) if instance.kind_of?(Hash) && atts.blank?
    raise 'expected first argument to be an Effective::Resource' unless resource.kind_of?(Effective::Resource)
    raise 'expected attributes to be a Hash' unless atts.kind_of?(Hash)

    instance = instance || instance_variable_get('@' + resource.name) || resource.instance
    raise "unable to find resource instance.  Either pass the instance as the second argument, or assign @#{resource.name}" unless instance

    crud = atts.delete(:crud) || false
    locals = atts.delete(:locals) || {}
    namespace = atts.delete(:namespace) || (resource.namespace.to_sym if resource.namespace)
    partial = atts.delete(:partial)

    partial = case partial
    when String
      partial
    when Symbol
      ['effective/resource/actions', partial.to_s].join('_')
    else
      'effective/resource/actions'
    end + '.html'.freeze

    actions = (crud ? resource.resource_crud_actions : resource.resource_actions)
    raise "unknown action for #{resource.name}: #{unknown}." if (unknown = (atts.keys - actions)).present?

    actions = actions - atts.reject { |_, v| v }.keys + atts.select { |_, v| v }.keys
    actions = actions.uniq.select { |action| EffectiveResources.authorized?(controller, action, resource) }

    locals = { resource: instance, effective_resource: resource, namespace: namespace, actions: actions }.compact.merge(locals)

    block_given? ? render((partial), locals) { yield } : render((partial), locals)
  end

  # When called from /admin/things/new.html.haml this will render 'admin/things/form', or 'things/form', or 'thing/form'
  def render_resource_form(resource, instance = nil, atts = {})
    (atts = instance; instance = nil) if instance.kind_of?(Hash) && atts.blank?
    raise 'expected first argument to be an Effective::Resource' unless resource.kind_of?(Effective::Resource)
    raise 'expected attributes to be a Hash' unless atts.kind_of?(Hash)

    instance = instance || instance_variable_get('@' + resource.name) || resource.instance
    raise "unable to find resource instance.  Either pass the instance as the second argument, or assign @#{resource.name}" unless instance

    action = atts.delete(:action)
    atts = { :namespace => (resource.namespace.to_sym if resource.namespace), resource.name.to_sym => instance }.compact.merge(atts)

    if lookup_context.template_exists?("form_#{action}", controller._prefixes, :partial)
      render "form_#{action}", atts
    elsif lookup_context.template_exists?('form', controller._prefixes, :partial)
      render 'form', atts
    elsif lookup_context.template_exists?('form', resource.plural_name, :partial)
      render "#{resource.plural_name}/form", atts
    elsif lookup_context.template_exists?('form', resource.name, :partial)
      render "#{resource.name}/form", atts
    else
      render 'form', atts  # Will raise the regular error
    end
  end

  def number_to_duration(duration)
    duration = duration.to_i
    value = duration.abs

    [
      ('-' if duration < 0),
      ("#{value / 60}h " if value >= 60),
      ("#{'%0.2d' % (value % 60)}m" if value > 0),
      ('0m' if value == 0),
    ].compact.join
  end

  ### Tableize attributes
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
