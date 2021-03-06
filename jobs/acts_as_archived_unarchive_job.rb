class ActsAsArchivedUnarchiveJob < ApplicationJob
  queue_as :default

  def perform(resource)
    cascade = resource.acts_as_archived_options[:cascade]

    cascade.each do |associated| 
      Array(resource.public_send(associated)).each { |resource| resource.unarchive! }
    end

    true
  end

end
