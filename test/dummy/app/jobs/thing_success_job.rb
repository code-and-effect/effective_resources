class ThingSuccessJob < ApplicationJob

  def perform(id)
    thing = Thing.find(id)
    thing.with_job_status { thing.success_job! }
  end

end
