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

  def number_to_duration(duration)
    duration = duration.to_i
    value = duration.abs

    [
      ('-' if duration < 0),
      ("#{value / 60}h " if value >= 60),
      "#{'%0.2d' % (value % 60)}m"
    ].compact.join
  end

  ### Icon Helpers for actions_column or elsewhere
  def show_icon_to(path, options = {})
    glyphicon_to('eye-open', path, {title: 'Show'}.merge(options))
  end

  def edit_icon_to(path, options = {})
    glyphicon_to('edit', path, {title: 'Edit'}.merge(options))
  end

  def destroy_icon_to(path, options = {})
    defaults = {title: 'Destroy', data: {method: :delete, confirm: 'Delete this item?'}}
    glyphicon_to('trash', path, defaults.merge(options))
  end

  def settings_icon_to(path, options = {})
    glyphicon_to('cog', path, {title: 'Settings'}.merge(options))
  end

  def ok_icon_to(path, options = {})
    glyphicon_to('ok', path, {title: 'OK'}.merge(options))
  end

  def approve_icon_to(path, options = {})
    glyphicon_to('ok', path, {title: 'Approve'}.merge(options))
  end

  def remove_icon_to(path, options = {})
    glyphicon_to('remove', path, {title: 'Remove'}.merge(options))
  end

  def glyphicon_to(icon, path, options = {})
    content_tag(:a, options.merge(href: path)) do
      if icon.start_with?('glyphicon-')
        content_tag(:span, '', class: "glyphicon #{icon}")
      else
        content_tag(:span, '', class: "glyphicon glyphicon-#{icon}")
      end
    end
  end
  alias_method :bootstrap_icon_to, :glyphicon_to
  alias_method :glyph_icon_to, :glyphicon_to


end
