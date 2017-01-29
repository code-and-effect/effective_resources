module EffectiveResourcesHelper

  def simple_form_submit(form, options = {class: 'text-right'}, &block)
    content_tag(:p, class: options[:class]) do
      [
        form.button(:submit, 'Save', data: { disable_with: 'Saving...' }),
        form.button(:submit, 'Save and Continue', data: { disable_with: 'Saving...' }),
        form.button(:submit, 'Save and Add New', data: { disable_with: 'Saving...' }),
        (capture(&block) if block_given?)
      ].compact.join(' ').html_safe
    end
  end

  def simple_form_save(form, options = {class: 'text-right'}, &block)
    content_tag(:p, class: options[:class]) do
      form.button(:submit, 'Save', data: { disable_with: 'Saving...' }) + (capture(&:block) if block_given?)
    end
  end

end
