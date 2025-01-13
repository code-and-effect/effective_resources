require 'test_helper'

class ActsAsPublishedTest < ActiveSupport::TestCase
  test 'acts as published' do
    thing = Thing.new(title: 'New Thing', body: 'body')
    assert thing.class.acts_as_published?

    assert thing.draft?
    assert thing.published_start_at.blank?
    assert thing.published_end_at.blank?
    thing.save!

    # Saves in published state when saved as an object
    assert thing.published?
  end

  test 'published by default when created from an object' do
    thing = Thing.new(title: 'New Thing', body: 'body')
    thing.save!
    assert thing.published?
    refute thing.draft?
  end

  test 'draft by default when created from a form' do
    thing = Thing.new(title: 'New Thing', body: 'body', save_as_draft: true)
    thing.save!
    refute thing.published?
    assert thing.draft?
  end

  test 'published in future' do
    thing = Thing.new(title: 'New Thing', body: 'body')
    thing.update!(published_start_at: Time.zone.now + 1.minute, published_end_at: nil)
    refute thing.published?
    assert thing.draft?
  end

  test 'published in past' do
    thing = Thing.new(title: 'New Thing', body: 'body')
    thing.update!(published_start_at: Time.zone.now - 1.day, published_end_at: Time.zone.now - 1.second)
    refute thing.published?
    assert thing.draft?
  end

  test 'published to draft' do
    thing = Thing.new(title: 'New Thing', body: 'body')
    thing.save!
    assert thing.published?
    refute thing.draft?

    assert_equal Time.zone.now.beginning_of_day, thing.published_start_at
    assert thing.published_end_at.blank?

    thing.draft!
    refute thing.published?
    assert thing.draft?
    assert thing.published_start_at.blank?
    assert thing.published_end_at.blank?
  end

  test 'draft to published keeps end date' do
    now = Time.zone.now

    thing = Thing.new(title: 'New Thing', body: 'body')
    thing.update!(published_start_at: now + 1.day, published_end_at: now + 2.days)
    refute thing.published?
    assert thing.draft?

    thing.publish!
    assert_equal Time.zone.now.beginning_of_day, thing.published_start_at
    assert_equal (now + 2.days), thing.published_end_at
  end

  test 'draft to published keeps end date again' do
    now = Time.zone.now

    thing = Thing.new(title: 'New Thing', body: 'body')
    thing.update!(published_start_at: nil, published_end_at: now)
    refute thing.published?
    assert thing.draft?

    thing.publish!
    assert_equal Time.zone.now.beginning_of_day, thing.published_start_at
    assert thing.published_end_at.blank?
  end

end
