module EffectiveBootstrap3Helper

  # An effective Bootstrap3 menu DSL
  # Automatically puts in the 'active' class based on request path

  # %ul.nav.navbar-nav.navbar-right
  #   = nav_link_to 'Sign In', new_user_session_path
  #   = nav_dropdown 'Settings' do
  #     = nav_link_to 'Account Settings', user_settings_path
  #     %li.divider
  #     = nav_link_to 'Sign In', new_user_session_path, method: :delete
  def nav_link_to(label, path, opts = {})
    content_tag(:li, class: ('active' if request.fullpath.include?(path))) do
      link_to(label, path, opts)
    end
  end

  def nav_dropdown(label, link_class: [], list_class: [], &block)
    raise 'expected a block' unless block_given?

    content_tag(:li, class: 'dropdown') do
      content_tag(:a, class: 'dropdown-toggle', href: '#', 'data-toggle': 'dropdown', role: 'button', 'aria-haspopup': 'true', 'aria-expanded': 'false') do
        label.html_safe + content_tag(:span, '', class: 'caret')
      end + content_tag(:ul, class: 'dropdown-menu') { yield }
    end
  end

  # An effective Bootstrap3 tabpanel DSL
  # Inserts both the tablist and the tabpanel

  # = tabs do
  #   = tab 'Imports' do
  #     %p Imports

  #   = tab 'Exports' do
  #     %p Exports

  # If you pass active 'label' it will make that tab active. Otherwise first.
  def tabs(active: nil, &block)
    raise 'expected a block' unless block_given?

    @_tab_mode = :panel
    @_tab_active = (active || :first)

    content_tag(:div, role: 'tabpanel') do
      content_tag(:ul, class: 'nav nav-tabs', role: 'tablist') { yield } # Yield to tab the first time
    end + content_tag(:div, class: 'tab-content') do
      @_tab_mode = :content
      @_tab_active = (active || :first)
      yield # Yield tot ab the second time
    end
  end

  def tab(label, &block)
    controls = label.to_s.downcase.to_param
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

end
