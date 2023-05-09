# frozen_string_literal: true

module EffectiveResourcesHelper
  # effective_bootstrap
  def effective_submit(form, options = {}, &block)
    actions = controller.try(:submits) || raise('controller must be an Effective::CrudController')
    actions = actions.select { |k, v| v[:default] != true } if options.delete(:defaults) == false
    actions = permitted_resource_actions(form.object, actions)

    submits = actions.map { |name, opts| form.save(name, opts.except(:action, :title, 'data-method') ) }.join.html_safe

    form.submit('', options) do
      (block_given? ? capture(&block) : ''.html_safe) + submits
    end
  end

  # effective_form_inputs
  def simple_form_submit(form, options = {}, &block)
    actions = controller.try(:submits) || raise('controller must be an Effective::CrudController')
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
    actions = controller.try(:buttons) || effective_resource.buttons()

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
    return ''.html_safe if resource.blank?

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
      "effective/resource/actions_#{partial}"
    else
      partial.presence || 'effective/resource/actions'
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
      render(
        partial: partial,
        formats: [:html],
        collection: resource,
        as: :resource,
        locals: locals.except(:resource),
        spacer_template: spacer_template
      )
    else
      render(partial: partial, formats: [:html], locals: locals)
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
    safe = atts.delete(:safe)
    atts = { :namespace => (effective_resource.namespace.to_sym if effective_resource.namespace), effective_resource.name.to_sym => resource }.compact.merge(atts)

    if lookup_context.template_exists?("form_#{action}", controller._prefixes, :partial)
      return render("form_#{action}", atts)
    end

    if lookup_context.template_exists?('form', controller._prefixes, :partial)
      return render('form', atts)
    end

    effective_resource.view_paths.each do |view_path|
      if lookup_context.template_exists?("form_#{action}", [view_path], :partial)
        return render(view_path + '/' + "form_#{action}", atts)
      end

      if lookup_context.template_exists?('form', [view_path], :partial)
        return render(view_path + '/' + 'form', atts)
      end
    end

    # Will raise the regular error
    return ''.html_safe if safe

    render('form', atts)
  end

  # Similar to render_resource_form
  def render_resource_partial(resource, atts = {})
    unless resource.kind_of?(ActiveRecord::Base) || resource.class.ancestors.include?(ActiveModel::Model)
      raise 'expected first argument to be an ActiveRecord or ActiveModel object'
    end

    raise 'expected attributes to be a Hash' unless atts.kind_of?(Hash)

    effective_resource = (atts.delete(:effective_resource) || find_effective_resource)

    action = atts.delete(:action)
    safe = atts.delete(:safe)
    atts = { :namespace => (effective_resource.namespace.to_sym if effective_resource.namespace), effective_resource.name.to_sym => resource }.compact.merge(atts)

    if lookup_context.template_exists?(effective_resource.name, controller._prefixes, :partial)
      return render(effective_resource.name, atts)
    end

    effective_resource.view_paths.each do |view_path|
      if lookup_context.template_exists?(effective_resource.name, [view_path], :partial)
        return render(view_path + '/' + effective_resource.name, atts)
      end
    end

    # Will raise the regular error
    return ''.html_safe if safe

    render(resource, atts)
  end
  alias_method :render_resource, :render_resource_partial

  def render_partial_exists?(partial, atts = {})
    raise('expected a path') unless partial.kind_of?(String)
    raise('path should not include spaces') if partial.include?(' ')

    pieces = partial.to_s.split('/') - [nil, '']

    file = pieces.last
    path = pieces[0..-2].join('/')

    lookup_context.exists?(file, [path], :partial)
  end

  def render_if_exists(partial, atts = {})
    render(partial, atts) if render_partial_exists?(partial, atts)
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

  def edit_effective_wizard?
    controller.class.try(:effective_wizard_controller?) && defined?(resource) && resource.draft?
  end

  def wizard_card(resource, &block)
    raise('expected a block') unless block_given?
    raise('expected an acts_as_wizard resource') unless resource.class.respond_to?(:acts_as_wizard?)

    step = resource.render_step
    raise('expected a render_step') unless step.present?

    title = resource.wizard_step_title(step)
    raise("expected a title for step #{step}") unless title.present?

    link = if edit_effective_wizard? && resource.is_a?(controller.resource_klass) && resource.can_visit_step?(step)
      link_to('Edit', wizard_path(step), title: "Edit #{title}")
    end

    content_tag(:div, class: 'card mb-4') do
      content_tag(:div, class: 'card-body') do
        content_tag(:div, class: 'row') do
          content_tag(:div, class: 'col-sm') do
            content_tag(:h5, title, class: 'card-title')
          end +
          content_tag(:div, class: 'col-sm-auto text-right') do
            (link || '')
          end
        end + capture(&block)
      end
    end
  end

  def return_to_dashboard_path
    path = (Tenant.routes.dashboard_path rescue nil) if defined?(Tenant) && Tenant.routes.respond_to?(:dashboard_path)
    path ||= (main_app.dashboard_path rescue nil) if main_app.respond_to?(:dashboard_path)
    path ||= (main_app.root_path rescue nil) if main_app.respond_to?(:root_path)

    path || '/'
  end

  # effective_translate
  def et(resource, attribute = nil)
    EffectiveResources.et(resource, attribute)
  end

  # effective_translate_plural
  def etd(resource, attribute = nil)
    EffectiveResources.etd(resource, attribute)
  end

  # effective_translate_plural
  def ets(resource, attribute = nil)
    EffectiveResources.ets(resource, attribute)
  end

  # effective_translate_plural
  def etsd(resource, attribute = nil)
    EffectiveResources.etsd(resource, attribute)
  end



end
