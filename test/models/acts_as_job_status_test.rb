require 'test_helper'

class ActsAsJobStatusTest < ActiveJob::TestCase
  test 'acts as job status success' do
    thing = Thing.new(title: 'New Thing', body: 'body')
    assert thing.class.acts_as_job_status?
    thing.save!

    assert thing.job_status.blank?

    assert_enqueued_with(job: ThingSuccessJob) { thing.success! }
    perform_enqueued_jobs

    thing.reload
    assert_equal 'Job Success', thing.title

    assert thing.job_status_completed?
    assert thing.job_started_at.present?
    assert thing.job_ended_at.present?
    assert thing.job_error.blank?
  end

  test 'acts as job status error' do
    ENV['TESTING_ACTS_AS_JOB_STATUS'] = 'true'

    thing = Thing.new(title: 'New Thing', body: 'body')
    thing.save!

    assert thing.job_status.blank?

    assert_enqueued_with(job: ThingErrorJob) { thing.error! }
    perform_enqueued_jobs

    thing.reload
    assert_equal 'New Thing', thing.title

    assert thing.job_status_error?
    assert thing.job_started_at.present?
    assert thing.job_ended_at.present?
    assert_equal "Validation failed: Cool Thing Title can't be blank, Body can't be blank", thing.job_error
  end

  test 'acts as job status fail' do
    ENV['TESTING_ACTS_AS_JOB_STATUS'] = 'true'

    thing = Thing.new(title: 'New Thing', body: 'body')
    thing.save!

    assert thing.job_status.blank?

    assert_enqueued_with(job: ThingFailJob) { thing.fail! }
    perform_enqueued_jobs

    thing.reload
    assert_equal 'New Thing', thing.title

    assert thing.job_status_error?
    assert thing.job_started_at.present?
    assert thing.job_ended_at.present?
    assert_equal "failed", thing.job_error
  end

end
