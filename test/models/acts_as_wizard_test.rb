require 'test_helper'

class ActsAsWizardTest < ActiveSupport::TestCase
  test 'acts as wizard' do
    thong = Thong.new

    assert Thong.acts_as_wizard?
    assert_equal [:start, :select, :finish], Thong::WIZARD_STEPS.keys
    assert_equal [:start, :select, :finish], thong.required_steps
  end

  test 'save step progress' do
    thong = Thong.new(title: 'Title', body: 'Body')

    assert_equal :start, thong.first_uncompleted_step
    assert thong.first_completed_step.nil?
    assert thong.last_completed_step.nil?

    thong.current_step = :start
    thong.save!

    assert thong.wizard_steps[:start].kind_of?(Time)

    assert_equal :start, thong.first_completed_step
    assert_equal :start, thong.last_completed_step

    assert_equal :select, thong.first_uncompleted_step
    assert thong.has_completed_previous_step?(:select)
  end

  test 'previous steps' do
    thong = Thong.new

    assert thong.previous_step(:start).nil?
    assert_equal :start, thong.previous_step(:select)
    assert_equal :select, thong.previous_step(:finish)
  end

end
