require 'test_helper'

class ActsAsStatusedTest < ActiveSupport::TestCase
  test 'acts as statused' do
    post = Post.new(title: 'New Post')
    assert Post.acts_as_statused?
    assert post.save!

    assert post.respond_to?(:draft_at)
    assert post.respond_to?(:draft_by)
    assert post.respond_to?(:draft!)
    assert post.respond_to?(:draft?)
    assert post.respond_to?(:was_draft?)

    assert post.respond_to?(:submitted_at)
    assert post.respond_to?(:submitted_by)
    assert post.respond_to?(:submitted!)
    assert post.respond_to?(:submitted?)
    assert post.respond_to?(:was_submitted?)

    assert post.respond_to?(:approved_at)
    assert post.respond_to?(:approved_by)
    assert post.respond_to?(:approved!)
    assert post.respond_to?(:approved?)
    assert post.respond_to?(:was_approved?)
  end

  test 'status steps' do
    user = User.create!(first_name: 'First', last_name: 'Last')
    post = Post.new(title: 'New Post', current_user: user)

    assert post.status.blank?

    assert post.save!
    assert_equal "draft", post.status
    assert post.draft?
    assert post.was_draft?

    assert post.submit!
    assert_equal "submitted", post.status
    refute post.draft?
    assert post.was_draft?
    assert post.submitted?
    assert post.was_submitted?

    assert post.approve!
    assert_equal "approved", post.status
    refute post.draft?
    refute post.submitted?
    assert post.was_draft?
    assert post.was_submitted?
    assert post.approved?
    assert post.was_approved?
  end

  test 'status_steps and dates' do
    user = User.create!(first_name: 'First', last_name: 'Last')
    now = Time.zone.now.beginning_of_hour

    post = Post.new(title: 'New Post', current_user: user)

    # Doesn't have a date field named Draft
    assert post.save!
    assert_equal now, post.draft_at.beginning_of_hour
    assert post.attributes.slice('draft_at').blank?          # Doesn't have an underlying attribute
    assert_equal now, post.status_steps[:draft_at].beginning_of_hour

    assert post.submit!
    assert_equal now, post.submitted_at.beginning_of_hour
    assert_equal now, post.attributes['submitted_at'].beginning_of_hour    # Does have an underlying attribute
    assert_equal now, post.status_steps[:submitted_at].beginning_of_hour

    assert post.approve!
    assert_equal now, post.approved_at.beginning_of_hour
    assert_equal now, post.attributes['approved_at'].beginning_of_hour    # Does have an underlying attribute
    assert_equal now, post.status_steps[:approved_at].beginning_of_hour
  end

  test 'status_steps and belongs_to' do
    user1 = User.create!(first_name: 'First', last_name: 'Last')
    user2 = User.create!(first_name: 'First', last_name: 'Last')
    user3 = User.create!(first_name: 'First', last_name: 'Last')

    now = Time.zone.now.beginning_of_hour

    post = Post.new(title: 'New Post')

    # Doesn't have a date field named Draft
    post.current_user = user1
    assert post.save!
    assert_equal user1, post.draft_by
    assert_equal user1.id, post.status_steps[:draft_by_id]
    assert_equal user1.class.name, post.status_steps[:draft_by_type]

    post.current_user = user2
    assert post.submit!
    assert_equal user2, post.submitted_by
    assert_equal user2.id, post.status_steps[:submitted_by_id]
    assert_equal user2.class.name, post.status_steps[:submitted_by_type]
    assert_equal user2.id, post.attributes['submitted_by_id']      # Does have an underlying attribute

    post.current_user = user3
    assert post.approve!
    assert_equal user3, post.approved_by
    assert_equal user3.id, post.status_steps[:approved_by_id]
    assert_equal user3.class.name, post.status_steps[:approved_by_type]
    assert post.attributes['approved_by_id'].blank?
  end

  test 'unsubmit' do
    user = User.create!(first_name: 'First', last_name: 'Last')
    post = Post.new(title: 'New Post', current_user: user)

    assert post.save!
    assert post.submitted!

    assert post.unsubmitted!

    # It rolled back to previous status
    assert post.draft?

    refute post.submitted?
    refute post.was_submitted?

    assert post.submitted_by.blank?
    assert post.submitted_by_id.blank?
    assert post.submitted_by_type.blank?
    assert post.attributes['submitted_at'].blank?

    refute post.status_steps.key?(:submitted_by_id)
    refute post.status_steps.key?(:submitted_by_type)
    refute post.status_steps.key?(:submitted_at)
  end

end
