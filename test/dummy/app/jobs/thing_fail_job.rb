class ThingFailJob < ApplicationJob

  def perform(id)
    thing = Thing.find(id)
    thing.with_job_status { thing.fail_job! }
  end

end
