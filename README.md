# Effective Resources

Make your controller an effective resource controller.

Implements the 7 RESTful actions as a one-liner on any controller.

## Getting Started

Add to your Gemfile:

```ruby
gem 'effective_resources'
```

Run the bundle command to install it:

```console
bundle install
```

## Usage

Add to your contoller:

```ruby
class PostsController < ApplicationController
  include Effective::CrudController

  protected

  def post_scope
    {client_id: current_user.client_id} # Or a symbol
  end

  def post_params
    params.require(:post).permit(:id, :title, :body)
  end

end
```

## What it does

Implements the 7 RESTful actions: `index`, `new`, `create`, `show`, `edit`, `update`, `destroy`.

- Loads an appropriate `@post` type instance
- Sets a `@page_title` (effective_pages).
- Calls authorize as per the configured `EffectiveResources.authorization_method` (flow through to CanCan or Pundit)
- Does the create/update save
- Sets a `flash[:success]` and redirects on success, or sets a `flash.now[:danger]` and renders on error.

## Helpers

### simple_form_submit

Call `simple_form_submit(f)` like follows:

```haml
= simple_form_for(post) do |f|
  = f.input :title
  = f.input :body

  = simple_form_submit(f)
```

to render 3 submit buttons: `Save`, `Save and Continue`, and `Save and Add New`.

## License

MIT License.  Copyright [Code and Effect Inc.](http://www.codeandeffect.com/)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Bonus points for test coverage
6. Create new Pull Request

