class ThongsController < ApplicationController
  include Effective::WizardController

  skip_before_action :clear_flash_success
end
