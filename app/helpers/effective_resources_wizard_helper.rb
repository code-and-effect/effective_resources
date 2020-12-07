# frozen_string_literal: true

module EffectiveResourcesWizardHelper

  def render_wizard_sidebar(resource, numbers: true, &block)
    sidebar = content_tag(:div, class: 'nav list-group wizard-sidebar') do
      resource.required_steps.map.with_index do |nav_step, index|
        render_wizard_sidebar_item(resource, nav_step, (index + 1 if numbers))
      end.join.html_safe
    end

    return sidebar unless block_given?

    content_tag(:div, class: 'row') do
      content_tag(:div, class: 'col-3') { sidebar } +
      content_tag(:div, class: 'col-9') { yield }
    end
  end

  def render_wizard_sidebar_item(resource, nav_step, index = nil)
    # From Controller
    current = (nav_step == step)
    title = resource_wizard_step_title(nav_step)

    # From Model
    disabled = !resource.can_visit_step?(nav_step)

    label = [index, title].compact.join('. ')
    klass = ['list-group-item', ('active' if current), ('disabled' if disabled && !current)].compact.join(' ')

    if (current || disabled)
      content_tag(:li, label, class: klass)
    else
      link_to(label, wizard_path(nav_step), class: klass)
    end
  end

end
