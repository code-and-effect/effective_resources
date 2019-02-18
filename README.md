# Effective Resources

The goal of this gem is to reduce the amount of code that needs to be written when developing a ruby on rails website.

It is ruby on rails, on effective rails.

A rails developer will always need to maintain and write:

- The `routes.rb` as it's the single most important file in an entire app.
- The `ability.rb` or other authorization.
- A normal active record model file for each model / form object / interaction / resource, whatever.
- A corresponding form.
- Any javascripts, etc, and unique resource actions.

However, all other patterns and a lot of code can be automated.

This gem replaces the following work a rails developer would normally do:

- Controllers.
- permitted params. This gem implements a model dsl to define and blacklist params. It's not the rails way.

- Any file named index/edit/show/new.html. We use rails application templates and powerful defaults views so these files need never be written.
- Figure out actions available to the `current_user` to each `resource` on the fly, based on controller namespace, the routes.rb and ability.rb
- Powerful helpers to render the correct resource action links.
- Collection of concern files.

Make your controller an effective resource controller.
Implements the 7 RESTful actions as a one-liner on any controller.
Reads the `routes.rb` and serves collection and member actions.

## Getting Started

```ruby
gem 'effective_resources'
```

Run the bundle command to install it:

```console
bundle install
```

Install the configuration file:

```console
rails generate effective_resources:install
```

The generator will install an initializer which describes all configuration options.

## Usage

Add to your `app/models/post.rb`:

```ruby
class Post < ApplicationRecord
  belongs_to :author, class_name: 'User'

  # The only thing this block is used for - right now - is permitted_params
  # So yo
  effective_resource do
    category      :string
    title         :string
    body          :text

    approved      :boolean, permitted: false   # You could write permitted: [:admin] to only permit this in the admin namespace

    timestamps
  end

  # The approve! action will be called by Effective::CrudController when submitted on a create/update or member action
  def approve!
    raise 'already approved' if approved?
    update!(approved: true)
  end

end
```

Add to your `routes.rb`:

```ruby
resources :posts, only: [:index, :show] do
  get :approve, on: :member
  post :approve, on: :member

  get :approved, on: :collection
  post :bulk_approve, on: :collection
end
```

Add to your contoller:

```ruby
class PostsController < ApplicationController
  include Effective::CrudController

  # Sets the @page_title in a before_filter
  page_title 'My Posts', only: [:index]

  # All queries and objects will be built with this scope
  resource_scope -> { current_user.posts }

  # Similar to above, with block syntax
  resource_scope do
    Post.active.where(user: current_user)
  end

  # The following methods are discovered from the routes.rb and defined automatically.
  # But you could also define them like this if you wanted.

  # When GET request, will render the approve page
  # When POST|PATCH|PUT request, will call @post.approve! and do the right thing
  member_action :approve

  # When GET request, will render an index page scoped to this method (if it's a scope on the model i.e. Post.approved)
  collection_action :approved

  # When POST|PATCH|PUT request, will call @post.approve! on each post as per params[:ids]
  # Created with effective_datatables bulk actions in mind
  collection_action :bulk_approve

  protected

  # The post_params are discovered from the model effective_resource do ... end block.
  # But you could also define them like this if you wanted.
  # Other recognized method names are posts_params and permitted_params
  def post_params
    params.require(:post).permit(:id, :author_id, :category, :title, :body)
  end

  # Pass /things/new?duplicate_id=3
  def duplicate_resource(resource)
    resource_klass.new(resource.attributes.slice('job_site', 'address'))
  end

end
```

## What it does

Implements the 7 RESTful actions: `index`, `new`, `create`, `show`, `edit`, `update`, `destroy`.

- Loads an appropriate `@posts` or `@post` type instance variable.
- Sets a `@page_title` (effective_pages).
- Calls authorize as per the configured `EffectiveResources.authorization_method` (flow through to CanCan or Pundit)
- Does the create/update save
- Sets a `flash[:success]` and redirects on success, or sets a `flash.now[:danger]` and renders on error.
- Does the right thing with member and collection actions
- Intelligently redirects based on commit message

## Bootstrap3 Helpers

### nav_link_to

Use `nav_link_to` and `nav_dropdown` to create bootstrap3 menus.

The helper automatically assigns the `active` class based on the request path.

```haml
%nav.navbar.navbar-default
  .container
    .navbar-header
      = link_to(image_tag('logo.png', alt: 'Logo'), '/', class: 'navbar-brand')
      %button.navbar-toggle.collapsed{data: {toggle: 'collapse', target: '.navbar-collapse', 'aria-expanded': false}}
        %span.icon-bar
        %span.icon-bar
        %span.icon-bar
    .collapse.navbar-collapse
      %ul.nav.navbar-nav.navbar-right
        - if current_user.present?
          - if can?(:index, Things)
            = nav_link_to 'Things', things_path

          = nav_dropdown 'Settings' do
            = nav_link_to 'Account Settings', user_settings_path
            %li.divider
            = nav_link_to 'Sign Out', destroy_user_session_path, method: :delete
        - else
          = nav_link_to 'Sign In', new_user_session_path
```

### tabs

Use `tabs do` and `tabs` to create bootstrap3 tabs.

The helper inserts both the tablist and the tabpanel, and assigns the `active` class.

```haml
= tabs do
  = tab 'Imports' do
    %p Imports

  = tab 'Exports' do
    %p Exports
```

You can also call `tabs(active: 'Exports') do` to set the active tab.

## Simple Form Helpers

### simple_form_submit

Call `simple_form_submit(f)` like follows:

```haml
= simple_form_for(post) do |f|
  = f.input :title
  = f.input :body

  = simple_form_submit(f)
```

to render 3 submit buttons: `Save`, `Save and Continue`, and `Save and Add New`.

### simple_form_save

Call `simple_form_save(f)` like follows:

```haml
= simple_form_for(post) do |f|
  ...
  = simple_form_save(f)
```

to render just the `Save` button, with appropriate data-disable, title, etc.

### Effective Form with

```ruby

= effective_form_with(model: user, url: user_settings_path) do |f|
  = effective_submit(f)
  = effective_save(f)

  = effective_save(f) do
    = f.save 'Save'
    = f.save 'Another'

  = effective_save(f, 'Save It')

  = effective_submit(f) do
    = f.save 'Will be appended'
```

### Remote Delete will automatically fade out the closest match

```
= link_to 'Delete', post_path(post), remote: true,
  data: { confirm: "Really delete #{post}?", method: :delete, closest: '.post' }
```

### acts_as_tokened

Quickly adds rails 5 `has_secure_token` to your model, along with some `Post.find()` enhancements to work with tokens instead of IDs.

This prevents enumeration of this resource.

Make sure to create a string `token` field on your model, then just declare `acts_as_tokened`.  There are no options.

### acts_as_archived

Create an 'archived' boolean filed in your model, then declare `acts_as_archived`.

Implements the dumb archived pattern.

An archived object should not be displayed on index screens, or any related resource's #new pages

effective_select (from the effective_bootstrap gem) is aware of this concern, and calls `.unarchived` and `.archived` appropriately when passed an ActiveRecord relation.

Use the cascade argument to cascade archived changes to any has_manys

```ruby
class Thing < ApplicationRecord
  has_many :comments
  acts_as_archivable cascade: :comments
end
```

Each controller needs its own archive and unarchive action.
To simplify this, use the following route concern.

In your routes.rb:

```ruby
Rails.application.routes.draw do
  acts_as_archived

  resource :things, concern: :acts_as_archived
  resource :comments, concern: :acts_as_archived
end
```

and include Effective::CrudController in your resource controller.

## License

MIT License.  Copyright [Code and Effect Inc.](http://www.codeandeffect.com/)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Bonus points for test coverage
6. Create new Pull Request

