require 'test_helper'

class ResourceScopeControllerTest < ActionDispatch::IntegrationTest
  test 'controller' do
    get resource_scope_index_url

    resource = @controller.effective_resource
    assert_equal Thing, resource.klass
    assert_equal [], resource.namespaces

    assert_equal '/resource_scope', @controller.resource_index_path
    assert_equal '/resource_scope/new', @controller.resource_new_path
  end

  test 'index' do
    get resource_scope_index_url
    assert_equal Thing.all.to_a, @controller.resources
    assert_equal [], @controller.view_context.assigns['things']
    assert_equal 'ThingsDatatable', @controller.view_context.assigns['datatable'].class.name
  end

  test 'new' do
    get new_resource_scope_url
    assert_response :success
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
  end

  test 'create valid' do
    post resource_scope_index_url, params: { thing: { title: 'Title', body: 'Body'} }
    assert_redirected_to resource_scope_path(Thing.last)
    assert_equal 'Successfully created Title', flash[:success]

    assert @controller.resource.kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].kind_of?(Thing)
    assert @controller.view_context.assigns['thing'].persisted?
  end

end
