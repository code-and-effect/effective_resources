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
      ("#{'%0.2d' % (value % 60)}m" if value > 0),
      ('0m' if value == 0),
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
