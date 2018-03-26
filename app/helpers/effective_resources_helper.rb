module EffectiveResourcesHelper

  def effective_submit(form, options = {}, &block) # effective_bootstrap
    resource = (@_effective_resource || Effective::Resource.new(controller_path))

    # Apply btn-primary to the first item, only if the class isn't already present
    actions = if controller.respond_to?(:submits_for)
      controller.submits_for(form.object)
    else
      {}.tap do |actions|
        actions['Save'] = { class: 'btn btn-primary' }

        if resource.action_path(:index) && EffectiveResources.authorized?(controller, :index, resource.klass)
          actions['Continue'] = { class: 'btn btn-secondary' }
        end

        if resource.action_path(:new) && EffectiveResources.authorized?(controller, :new, resource.klass)
          actions['Add New'] = { class: 'btn btn-secondary' }
        end
      end
    end

    # Group by class and render
    buttons = actions.group_by { |_, opts| opts[:class] }.flat_map do |_, btns|
      btns.map { |name, opts| form.save(name, opts) }
    end.join.html_safe

    effective_save(form) do
      (block_given? ? capture(&block) : ''.html_safe) + buttons
    end

  end

  def effective_save(form, label = 'Save', &block) # effective_bootstrap
    wrapper = (form.layout == :horizontal) ? { class: 'form-group form-actions row' } : { class: 'form-group form-actions' }

    content_tag(:div, wrapper) do
      icon('spinner') + (block_given? ? capture(&block) : form.save(label, class: 'btn btn-primary'))
    end
  end

  def effective_save_button(form, label = 'Save', &block)
    content_tag(:div, class: 'form-actions') do
      icon('spinner') + (block_given? ? capture(&block) : form.save(label, class: 'btn btn-primary'))
    end
  end

  # effective_form_inputs
  def simple_form_submit(form, options = {}, &block)
    resource = (@_effective_resource || Effective::Resource.new(controller_path))

    # Apply btn-primary to the first item, only if the class isn't already present
    actions = if controller.respond_to?(:submits_for)
      controller.submits_for(form.object)
    else
      {}.tap do |actions|
        actions['Save'] = { class: 'btn btn-primary', data: { disable_with: 'Saving...' }}

        if resource.action_path(:index) && EffectiveResources.authorized?(controller, :index, resource.klass)
          actions['Continue'] = { class: 'btn btn-default', data: { disable_with: 'Saving...' }}
        end

        if resource.action_path(:new) && EffectiveResources.authorized?(controller, :new, resource.klass)
          actions['Add New'] = { class: 'btn btn-default', data: { disable_with: 'Saving...' }}
        end
      end
    end

    wrapper_options = { class: 'form-actions' }.merge(options.delete(:wrapper_html) || {})

    content_tag(:div, wrapper_options) do
      buttons = actions.group_by { |_, args| args[:class] }.flat_map do |_, action|
        action.map { |action| form.button(:submit, *action) } + ['']
      end

      # I think this is a bug. I can't override default button class when passing my own class: variable. it merges them.
      if defined?(SimpleForm) && (btn_class = SimpleForm.button_class).present?
        buttons = buttons.map { |button| button.sub(btn_class, '') }
      end

      if block_given?
        buttons = [capture(&block), ''] + buttons
      end

      buttons.join('&nbsp;').html_safe
    end
  end

  def simple_form_save(form, label = 'Save', options = {}, &block)
    wrapper_options = { class: 'form-actions' }.merge(options.delete(:wrapper_html) || {})
    options = { class: 'btn btn-primary', data: { disable_with: 'Saving...'} }.merge(options)

    content_tag(:div, wrapper_options) do
      form.button(:submit, label, options) + (capture(&block) if block_given?)
    end
  end

  # When called from /admin/things/new.html.haml this will render 'admin/things/form', or 'things/form', or 'thing/form'
  def render_resource_form(resource)
    atts = {:namespace => (resource.namespace.to_sym if resource.namespace.present?), resource.name.to_sym => instance_variable_get('@' + resource.name)}.compact

    if lookup_context.template_exists?('form', controller._prefixes, :partial)
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
