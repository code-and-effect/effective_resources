require_relative "boot"

require "rails/all"
require 'sprockets/rails'

Bundler.require(*Rails.groups)

require 'haml'
require 'wicked'
require 'pry-byebug'
require "effective_resources"
require "effective_datatables"

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Required for testing
    config.active_record.use_yaml_unsafe_load = true
    config.active_job.queue_adapter = :inline
  end
end
