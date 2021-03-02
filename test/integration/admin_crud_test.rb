require 'test_helper'

class AdminCrudTest < ActionDispatch::IntegrationTest
  test 'controller' do
    get admin_things_url

    assert_equal '/admin/things', @controller.resource_index_path
    assert_equal '/admin/things/new', @controller.resource_new_path

    resource = @controller.effective_resource
    assert_equal Thing, resource.klass
    assert_equal ['admin'], resource.namespaces
  end

  test 'index' do
    get admin_things_url
    assert_equal Thing.all.to_a, @controller.resources
    assert_equal [], @controller.view_context.assigns['things']
    assert_equal 'Admin::ThingsDatatable', @controller.view_context.assigns['datatable'].class.name
  end

  test 'new' do
    get new_admin_thing_url
    assert_response :success
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
  end

  test 'create valid' do
    post admin_things_url, params: { thing: { title: 'Title', body: 'Body'} }
    assert_redirected_to admin_thing_path(Thing.last)
    assert_equal 'Successfully created Title', flash[:success]

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].persisted?
  end

  test 'create invalid' do
    post admin_things_url, params: { thing: { title: 'Title', body: nil} }
    assert_response :success
    assert_equal "Unable to create Title: body can't be blank", flash[:danger]
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].errors.present?
  end

  test 'edit' do
    thing = Thing.create!(title: 'Title', body: 'Body')

    get edit_admin_thing_url(thing)
    assert_response :success
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].persisted?
  end

  test 'update valid' do
    thing = Thing.create!(title: 'Title', body: 'Body')

    patch admin_thing_url(thing), params: { thing: { id: thing.id, title: 'Title2', body: 'Body2'} }
    assert_equal 'Successfully updated Title2', flash[:success]
    assert_redirected_to edit_admin_thing_path(thing)

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].persisted?
  end

  test 'update invalid' do
    thing = Thing.create!(title: 'Title', body: 'Body')

    patch admin_thing_url(thing), params: { thing: { id: thing.id, title: 'Title2', body: nil} }
    assert_response :success
    assert_equal "Unable to update Title2: body can't be blank", flash[:danger]
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].errors.present?
  end

  test 'destroy' do
    thing = Thing.create!(title: 'Title', body: 'Body')

    delete admin_thing_url(thing)
    assert_equal 'Successfully deleted thing', flash[:success]
    assert_redirected_to admin_things_path
  end

  test 'report collection action' do
    get report_admin_things_url
    assert_equal Thing.all.to_a, @controller.resources
    assert_equal [], @controller.view_context.assigns['things']
  end

  test 'approve member action valid' do
    thing = Thing.create!(title: 'Title', body: 'Body')
    post approve_admin_thing_url(thing), params: { thing: { title: 'Title2', body: 'Body2'} }

    assert_equal 'Successfully approved Title2', flash[:success]
    assert_redirected_to edit_admin_thing_path(thing)

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].persisted?
  end

  test 'approve member action invalid' do
    thing = Thing.create!(title: 'Title', body: 'Body')

    post approve_admin_thing_url(thing), params: { thing: { title: 'Title2', body: nil} }
    assert_redirected_to edit_admin_thing_path(thing)
    assert_equal "Unable to approve Title2: body can't be blank", flash[:danger]

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].errors.present?
  end

  test 'approve member action invalid from edit' do
    thing = Thing.create!(title: 'Title', body: 'Body')

    post approve_admin_thing_url(thing),
      params: { thing: { title: 'Title2', body: nil} },
      headers: { 'Referer': edit_admin_thing_url(thing) }

    assert_response :success
    assert_equal "Unable to approve Title2: body can't be blank", flash[:danger]
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].errors.present?
  end

end
