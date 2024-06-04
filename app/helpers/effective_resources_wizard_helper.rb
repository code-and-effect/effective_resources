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
      link_to(label, path || wizard_path(nav_step), class: klass, 'data-turbolinks': false)
    end
  end

  def render_wizard_resource_step(resource, step, as: nil, path: nil)
    render_wizard_resource(resource, only: step, as: as, path: path)
  end

  def render_wizard_resource(resource, only: [], except: [], as: nil, path: nil)
    effective_resource = Effective::Resource.new(resource)

    # Render path
    as ||= effective_resource.name
    path ||= effective_resource.wizard_file_path(resource)
    raise('expected a path') unless path.present?

    resource.render_path = path.to_s.chomp('/')

    # Render steps
    only = Array(only)
    except = Array(except)

    steps = resource.render_steps
    steps = (steps - except) if except.present?
    steps = (steps & only) if only.present?

    steps.map do |step|
      resource.render_step = step

      render_if_exists("#{path}/#{step}", as.to_sym => resource) || render('effective/acts_as_wizard/wizard_step', resource: resource, resource_path: path)
    end.join.html_safe
  end

end
