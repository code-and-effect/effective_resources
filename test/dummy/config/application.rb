require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)

require 'pry-byebug'
require 'haml'
require "effective_resources"
require "effective_datatables"

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    config.active_record.use_yaml_unsafe_load = true
  end
end
