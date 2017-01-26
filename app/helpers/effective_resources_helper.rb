module EffectiveResourcesHelper

  def simple_form_submit(form)
    content_tag(:p, class: 'text-right') do
      [
        form.button(:submit, 'Save', data: { disable_with: 'Saving...' }),
        form.button(:submit, 'Save and Continue', data: { disable_with: 'Saving...' }),
        form.button(:submit, 'Save and Add New', data: { disable_with: 'Saving...' })
      ].join(' ').html_safe
    end
  end

  def simple_form_save(form)
    content_tag(:p, class: 'text-right') do
      form.button(:submit, 'Save', data: { disable_with: 'Saving...' })
    end
  end

end
