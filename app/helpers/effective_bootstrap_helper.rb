# Boostrap4 Helpers

module EffectiveBootstrapHelper
  # Nav links and dropdowns
  # Automatically puts in the 'active' class based on request path

  # %ul.navbar-nav
  #   = nav_link_to 'Sign In', new_user_session_path
  #   = nav_dropdown 'Settings' do
  #     = nav_link_to 'Account Settings', user_settings_path
  #     = nav_dropdown_divider
  #     = nav_link_to 'Sign In', new_user_session_path, method: :delete
  def nav_link_to(label, path, opts = {})
    if @_nav_mode == :dropdown  # We insert dropdown-items
      return link_to(label, path, merge_class_key(opts, 'dropdown-item'))
    end

    # Regular nav link item
    content_tag(:li, class: (request.fullpath.include?(path) ? 'nav-item active' : 'nav-item')) do
      link_to(label, path, merge_class_key(opts, 'nav-link'))
    end
  end

  def nav_dropdown(label, right: false, link_class: [], list_class: [], &block)
    raise 'expected a block' unless block_given?

    id = "dropdown-#{''.object_id}"

    content_tag(:li, class: 'nav-item dropdown') do
      content_tag(:a, class: 'nav-link dropdown-toggle', href: '#', id: id, role: 'button', 'data-toggle': 'dropdown', 'aria-haspopup': true, 'aria-expanded': false) do
        label.html_safe
      end + content_tag(:div, class: (right ? 'dropdown-menu dropdown-menu-right' : 'dropdown-menu'), 'aria-labelledby': id) do
        @_nav_mode = :dropdown; yield; @_nav_mode = nil
      end
    end
  end

  def nav_divider
    content_tag(:div, '', class: 'dropdown-divider')
  end

  # An effective Bootstrap3 tabpanel DSL
  # Inserts both the tablist and the tabpanel

  # = tabs do
  #   = tab 'Imports' do
  #     %p Imports

  #   = tab 'Exports' do
  #     %p Exports

  # If you pass active 'label' it will make that tab active. Otherwise first.
  def tabs(active: nil, panel: {}, list: {}, content: {}, &block)
    raise 'expected a block' unless block_given?

    @_tab_mode = :panel
    @_tab_active = (active || :first)

    content_tag(:div, {role: 'tabpanel'}.merge(panel)) do
      content_tag(:ul, {class: 'nav nav-tabs', role: 'tablist'}.merge(list)) { yield } # Yield to tab the first time
    end + content_tag(:div, {class: 'tab-content'}.merge(content)) do
      @_tab_mode = :content
      @_tab_active = (active || :first)
      yield # Yield tot ab the second time
    end
  end

  def tab(label, controls = nil, &block)
    controls ||= label.to_s.parameterize.gsub('_', '-')
    controls = controls[1..-1] if controls[0] == '#'

    active = (@_tab_active == :first || @_tab_active == label)

    @_tab_active = nil if @_tab_active == :first

    if @_tab_mode == :panel # Inserting the label into the tabpanel top
      content_tag(:li, role: 'presentation', class: ('active' if active)) do
        content_tag(:a, href: '#' + controls, 'aria-controls': controls, 'data-toggle': 'tab', role: 'tab') do
          label
        end
      end
    else # Inserting the content into the tab itself
      content_tag(:div, id: controls, class: "tab-pane#{' active' if active}", role: 'tabpanel') do
        yield
      end
    end
  end

  def merge_class_key(hash, value)
    return { :class => value } unless hash.kind_of?(Hash)

    if hash[:class].present?
      hash.merge!(:class => "#{hash[:class]} #{value}")
    else
      hash.merge!(:class => value)
    end
  end

end
