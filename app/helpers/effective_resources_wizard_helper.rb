# frozen_string_literal: true

module EffectiveResourcesWizardHelper

  def render_wizard_sidebar(resource, numbers: true, path: nil, horizontal: false, &block)
    if path.present?
      raise('expected path to be a string with /build/ in it ') unless path.to_s.include?('/build/')
      path = path.split('/build/').first + '/build/'
    end

    klasses = ['wizard-sidebar', 'list-group', ('list-group-horizontal' if horizontal)].compact.join(' ')

    sidebar = content_tag(:div, class: klasses) do
      resource.sidebar_steps.map.with_index do |nav_step, index|
        render_wizard_sidebar_item(resource, nav_step: nav_step, index: (index + 1 if numbers), path: (path + nav_step.to_s if path))
      end.join.html_safe
    end

    return sidebar unless block_given?

    content_tag(:div, class: 'row') do
      content_tag(:div, class: 'col-lg-3') { sidebar } +
      content_tag(:div, class: 'col-lg-9') { yield }
    end
  end

  def render_wizard_sidebar_item(resource, nav_step:, path: nil, index: nil)
    # From Controller
    current = (nav_step == step)
    title = resource_wizard_step_title(resource, nav_step)

    # From Model
    disabled = !resource.can_visit_step?(nav_step)

    label = [index, title].compact.join('. ')
    klass = ['list-group-item', 'list-group-item-action', ('active' if current), ('disabled' if disabled && !current)].compact.join(' ')

    if (current || disabled)
      content_tag(:a, label, class: klass)
    else
      link_to(label, path || wizard_path(nav_step), class: klass)
    end
  end

  def render_wizard_resource(resource, as: nil, path: nil)
    effective_resource = Effective::Resource.new(resource)

    as ||= effective_resource.name
    path ||= effective_resource.view_file_path(nil)
    raise('expected a path') unless path.present?

    resource.render_path = path.to_s.chomp('/')

    resource.render_steps.map do |partial|
      resource.render_step = partial

      render_if_exists("#{path}/#{partial}", as.to_sym => resource) || render('effective/acts_as_wizard/wizard_step', resource: resource, resource_path: path)
    end.join.html_safe
  end

end
