# ActsAsJobStatus
#
# Tracks the status of background jobs. Intended to be used in a wizard.
#
# Mark your model with 'acts_as_job_status' 
#
# Add the the following columns
#
# job_status            :string
# job_started_at        :datetime
# job_ended_at          :datetime
# job_error             :text
#
# Use with_job_status in your background job

module ActsAsJobStatus
  extend ActiveSupport::Concern

  module Base
    def acts_as_job_status(options = nil)
      include ::ActsAsJobStatus
    end
  end

  included do
  end

  module ClassMethods
    def acts_as_job_status?; true; end
  end

  # Instance Methods

  def perform_with_job_status!(&block)
    assign_attributes(job_status: nil, job_started_at: nil, job_ended_at: nil, job_error: nil)

    after_commit { yield }

    save!
  end

  def job_status_display_item_counts?
    job_status_completed_items_count.present? && job_status_total_items_count.present?
  end

  def job_status_completed_items_count
    nil
  end

  def job_status_total_items_count
    nil
  end

  def job_status_enqueued?
    job_status == 'enqueued'
  end

  def job_status_running?
    job_status == 'running'
  end

  def job_status_completed?
    job_status == 'completed'
  end

  def job_status_error?
    job_status == 'error'
  end

  def with_job_status(&block)
    self.class.where(id: id).update_all(
      job_status: :running,
      job_started_at: Time.zone.now,
      job_ended_at: nil,
      job_error: nil
    )

    exception = nil
    job_status = nil
    job_error = nil

    begin
      success = yield
      raise('Unexpected error') unless success

      job_status = :completed
    rescue Exception => e
      exception = e
      job_status = :error
      job_error = e.message.presence || 'Unexpected error'
    end

    self.class.where(id: id).update_all(
      job_status: job_status, 
      job_ended_at: Time.zone.now, 
      job_error: job_error
    )

    if job_status == :error
      EffectiveLogger.error(exception.message, associated: self) if defined?(EffectiveLogger)
      ExceptionNotifier.notify_exception(exception, data: { id: id, class_name: self.class.name }) if defined?(ExceptionNotifier)
    end

    if job_status == :error && !ENV['TESTING_ACTS_AS_JOB_STATUS']
      raise(exception) unless Rails.env.production? || Rails.env.staging?
    end

    true
  end

end
