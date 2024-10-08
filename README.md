# Effective Resources

This gem looks at the current `routes.rb`, authorization `ability.rb`, `current_user` and controller context
to metaprogram an effective CRUD website.

It automates linking to resource edit, show, delete pages, as well as member and collection actions.

It totally replaces your controller, and instead provides a simple DSL to route actions based on your form `params[:commit]`.

The goal of this gem is to reduce the amount of code that needs to be written when developing a ruby on rails website.

It's ruby on rails, on effective rails.


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

Check the `config/initializer/effective_resources.rb` and make sure it's calling your authentication library correctly.

```
config.authorization_method = Proc.new { |controller, action, resource| authorize!(action, resource) } # CanCanCan
```

## Workflow

A rails developer will **always** need to maintain and write:

- The `routes.rb` as it's the single most important file in an entire app.
- The `ability.rb` or other authorization.
- A normal ApplicationRecord model file for each model, `/app/models/post.rb`.
- Its corresponding form, `/app/views/posts/_form.html.haml` and `_post.html.haml`
- Any javascript and css

However, all other areas of code should be automated.

This gem **replaces** the following work a rails developer would normally do:

- Controllers.
- Any file named `index/edit/show/new.html`. We use rails application templates and powerful defaults views so these files need never be written.
- Writing `permitted params`. This gem implements a model dsl to define and blacklist params.
- Manually checking which actions are available to the `current_user` on each `resource` all the time.
- Writing submit buttons


# Quick Start

This gem was built to quickly build CRUD interfaces. Automate all the actions, and submit buttons.

It uses the `params[:commit]` message to call the appropriate action, or `save` on the given resource.

It reads the `routes.rb` to serve `collection` and `member` actions, and considers `current_user` and `ability.rb`

Tries to do the right thing in all situations.

Add to your `app/models/post.rb`:

```ruby
class Post < ApplicationRecord
  belongs_to :author, class_name: 'User'

  # The only thing this block is used for - right now - is permitted_params
  effective_resource do
    category      :string
    title         :string
    body          :text

    approved      :boolean, permitted: false   # You could write permitted: [:admin] to only permit this in the admin namespace

    timestamps
  end

  # The approve! action will be called by Effective::CrudController when submitted on a create/update or member action
  def approve!
    raise 'already approved' if approved?s
    update!(approved: true)
  end
end
```

Add to your `routes.rb`:

```ruby
resources :posts
```

Add to your contoller:

```ruby
class PostsController < ApplicationController
  include Effective::CrudController

  submit :approve, 'Approve'
end
```

and in your view:

```ruby
  = form_with(model: post) do
    = f.input :text
    = effective_submit(f)  # Will make a Save and an Approve. Rails 5 forms.
    = simple_form_submit(f) # Ditto.
```

and in your authorization:

```ruby
  can :approve, Post
  # can(:approve, Post) { |post| !post.approved? }
```

## Controller

Implements the 7 RESTful actions: `index`, `new`, `create`, `show`, `edit`, `update`, `destroy`.

- Loads an appropriate `@posts` or `@post` type instance variable.
- Sets a `@page_title` (effective_pages).
- Calls authorize as per the configured `EffectiveResources.authorization_method` (flow through to CanCan or Pundit)
- Does the create/update save
- Sets a `flash[:success]` and redirects on success, or sets a `flash.now[:danger]` and renders on error.
- Does the right thing with member and collection actions
- Intelligently redirects based on commit message

You can override individual methods on the CrudController.

Here is a more advanced example:

```ruby
class PostsController < ApplicationController
  include Effective::CrudController
  # Sets the @page_title in a before_filter
  page_title 'My Posts', only: [:index]

  # Callbacks: before_render, before_save, after_save, after_error, after_commit
  before_render(only: :new) do
    resource.client = current_user.clients.first
  end

  submit :accept, 'Accept',
    if: -> { !resource.approved? }, # Imho this check should be kept in ability.rb, but you could do it here.
    redirect: -> { accepted_posts_path },
    success: 'The @resource has been approved' # Any @resource will be replaced with @resource.to_s

  # All queries and objects will be built with this scope
  resource_scope -> { current_user.posts }

  # Similar to above, with block syntax
  resource_scope do
    Post.active.where(user: current_user)
  end

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

## Helpers

### effective_submit & simple_form_submit

```rails
= form_with(model: post) do |f|
  = effective_submit(f)
  = simple_form_submit(f)
```

These helpers output the `= f.submit 'Save'` based on the controllers `submits`, the `current_user` and `ability.rb`.

They try to add good `data-confirm` options for `delete` buttons and sort by `btn-primary`, `btn-secondary` and `btn-danger`.

### Application Templates

When you installed the gem, it should make some `views/application/index.html.haml`, `new.html.haml`, etc.

If you're not using haml, you should be, go install `haml`. Or convert to slim, you sly devils.

These files, possibly customized to your app, should replace almost all resource specific views.

Just create a `_form.html.haml` and `_post.html.haml` for each resource.

Just put another `app/views/posts/index.html.haml` in the posts directory to override the default template.


## Concerns

Sure why not. These don't really fit into my code base anywhere else.

### acts_as_paginable

Quickly adds a `paginate` scope to your model that can then be used in your views and also integrates well with `effective_bootstrap`. The pagination method is `Limit and Offset`.

```ruby
# Given any model you just need to call it like
class Thing < ApplicationRecord
  acts_as_paginable
end

# Now you can use it like:
Thing.all.paginate(page: 1, per_page: 5)
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

### acts_as_wizard

Build up an object through a wizard.

Works with the [wicked](https://github.com/zombocom/wicked) gem to create wizard quickly.

Create a model and define `acts_as_wizard`:

```ruby
class Thing < ApplicationRecord
  acts_as_wizard(
    start: 'Start',
    select: 'Select',
    finish: 'Finish'
  )

  effective_resource do
    title       :string
    wizard_steps  :text, permitted: false
  end

  validates :title, presence: true

  def to_s
    title.presence || 'New Thing'
  end

  # If you define a bang method matching the name of a step
  # it will be called when that step is submitted.
  # Otherwise save! is called.
  def select!
    ApplicationMailer.selected(self).deliver_later
    save!
  end

  # An array of steps that the controller will use
  # Default value is just all of them. But you can customize here
  # def required_steps
  #   steps = WIZARD_STEPS.keys
  #   selectable? ? steps : steps - [:select]
  # end

  # Control whether the user has permission to visit this step
  #
  # This is the default, can go forward or back:
  #
  # def can_visit_step?(step)
  #   can_revisit_completed_steps(step)
  # end
  #
  # Easy change if you only want to go forward:
  #
  # def can_visit_step?(step)
  #   cannot_revisit_completed_steps(step)
  # end
  #
  # or custom algorithm:
  #
  # def can_visit_step?(step)
  #   return false unless has_completed_previous_step?(step)
  #   return false if has_completed_step?(:finish) && step != :finish
  # end
end
```

In your routes:

```ruby
resources :things, only: [:index, :show, :new, :destroy] do
  resources :build, controller: :things, only: [:show, :update]
end
```

Make a controller:

```ruby
class ThingsController < ApplicationController
  include Effective::WizardController
end
```

And then create one view per step.

Here's `views/things/start.html.haml`:

```haml
= render_wizard_sidebar(resource) do
  %h1= @page_title

  = effective_form_with(model: resource, url: wizard_path(step), method: :put) do |f|
    = f.text_field :title
    = f.submit 'Save and Continue'
```

You can also call `render_wizard_sidebar(resource)` without the block syntax.

If you add `f.hidden_field(:skip_to_step, value: 'stepc')` you can control the next step.

## Select2 Ajax Controller

This gem provides an admin endpoint for select2 AJAX to fetch users.

To use this endpoint please add

```
can :users, :ajax
```

And then create a select field like this:

```
= f.select :user_id, current_user.class.all, ajax_url: effective_resources.users_effective_ajax_index_path
```

To format the results, add a method to your User class. Should return HTML with a span tag

```
def to_select2
  "<span>#{first_name} #{last_name}</span> <small>&lt;#{try(:public_email) || email}&gt;</small>"
end
```

## Authentication
Effective Resources is designed to work with Devise. It also adds support for an `alternate email`
for authentication. You just need to add an `alternate_email` column to your `User` model table.

After that column is added, any user would be able to log in with either their `email` or their
`alternate_email`.

You can also create another mailer for `devise` in order to send password reset emails to the both
the primary `email` and also the `alternate_email`, like this:

```ruby
class DeviseMailer < Devise::Mailer
  # Overriding Devise's #headers_for to support alternate_email when present
  def headers_for(action, opts)
    headers = super(action, opts)

    if [:reset_password_instructions].include?(action)
      headers.merge!(
        to: [resource.email, resource.try(:alternate_email)].compact.uniq
      )
    end

    headers
  end
end
```

and set this new mailer to be used by `devise` in `config/initializers/devise.rb`:

```ruby
Devise.setup do |config|
  # ...
  config.mailer = 'DeviseMailer'
  # ...
end
```

## Testing

Run tests by:

```ruby
rails test
```

## License

MIT License. Copyright [Code and Effect Inc.](http://www.codeandeffect.com/)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Bonus points for test coverage
6. Create new Pull Request
