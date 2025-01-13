class ThingErrorJob < ApplicationJob

  def perform(id)
    thing = Thing.find(id)
    thing.with_job_status { thing.error_job! }
  end

end
