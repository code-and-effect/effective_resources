require 'test_helper'
require 'wicked'

class WizardControllerTest < ActionDispatch::IntegrationTest
  test 'index route works' do
    get thongs_url

    assert_equal Thong.all.to_a, @controller.resources
    assert_equal [], @controller.view_context.assigns['thongs']
  end

  test 'new route redirects to start page' do
    get new_thong_url
    assert_redirected_to thong_build_path(:new, :start)
    assert_redirected_to @controller.resource_wizard_path(:new, :start)
  end

  test 'destroy' do
    thong = Thong.create!(title: 'Title', body: 'Body', current_step: :start)

    delete thong_path(thong)
    assert_equal 'Successfully deleted Title', flash[:success]
    assert_redirected_to thongs_path
  end

  test 'first step' do
    get thong_build_path(:new, :start)

    assert_response :success
    assert_match "<form", @response.body

    assert_equal Thong::WIZARD_STEPS.keys, @controller.wizard_steps
    assert_equal Thong::WIZARD_STEPS.keys, @controller.resource_wizard_steps

    assert_equal Thong::WIZARD_STEPS[:start], @controller.view_context.assigns['page_title']
    assert_equal Thong::WIZARD_STEPS[:start], @controller.resource_wizard_step_title(:start)

    assert @controller.resource.kind_of?(Thong)
    assert @controller.view_context.assigns['thong'].kind_of?(Thong)
    assert @controller.view_context.assigns['thong'].new_record?

    assert @controller.view_context.resource.kind_of?(Thong)
    assert @controller.view_context.resource.new_record?

    assert_equal :start, @controller.resource.current_step
  end

  test 'save step valid' do
    put thong_build_path(thong_id: :new, id: :start), params: { thong: { title: 'Title', body: 'Body'} }

    assert_redirected_to thong_build_path(Thong.last, :select)
    assert_equal 'Successfully saved', flash[:success]

    assert @controller.resource.kind_of?(Thong)
    assert @controller.resource.persisted?
  end

  test 'save step invalid' do
    put thong_build_path(thong_id: :new, id: :start), params: { thong: { title: '', body: ''} }

    assert_response :success
    assert_equal "Errors occurred while trying to save.", flash[:danger]
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Thong)
    assert @controller.view_context.assigns['thong'].kind_of?(Thong)
    assert @controller.view_context.assigns['thong'].errors.present?
    assert_equal :start, @controller.resource.current_step
  end

  test 'resource show redirects to wizard show' do
    thong = Thong.create!(title: 'Title', body: 'Body', current_step: :start)

    get thong_path(thong)
    assert_redirected_to thong_build_path(Thong.last, :select)
  end

  test 'visit invalid wicked wizard step' do
    get thong_build_path(:new, :asdf)
    assert_redirected_to thong_build_path(:new, :start)

    assert_equal "Unknown step. You have been moved to the start step.", flash[:danger]
  end

  test 'enforce_can_visit_step' do
    thong = Thong.create!(title: 'Title', body: 'Body', current_step: :start)

    get thong_build_path(Thong.last, :finish)
    assert_equal "You have been redirected to the Select step.", flash[:danger]

    assert_redirected_to thong_build_path(Thong.last, thong.first_uncompleted_step)
  end

end
