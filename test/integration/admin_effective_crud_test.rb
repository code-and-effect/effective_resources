require 'test_helper'

class AdminEffectiveCrudTest < ActionDispatch::IntegrationTest
  test 'controller' do
    get admin_thangs_url

    assert_equal '/admin/thangs', @controller.resource_index_path
    assert_equal '/admin/thangs/new', @controller.resource_new_path

    resource = @controller.effective_resource
    assert_equal Effective::Thang, resource.klass
    assert_equal ['admin'], resource.namespaces
  end

  test 'index' do
    get admin_thangs_url
    assert_equal Effective::Thang.all.to_a, @controller.resources
    assert_equal [], @controller.view_context.assigns['thangs']
    assert_equal 'Admin::EffectiveThangsDatatable', @controller.view_context.assigns['datatable'].class.name
  end

  test 'new' do
    get new_admin_thang_url
    assert_response :success
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].kind_of?(Effective::Thang)
  end

  test 'create valid' do
    post admin_thangs_url, params: { effective_thang: { title: 'Title', body: 'Body'} }
    assert_redirected_to admin_thang_path(Effective::Thang.last)
    assert_equal 'Successfully created Title', flash[:success]

    assert @controller.resource.kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].persisted?
  end

  test 'create invalid' do
    post admin_thangs_url, params: { effective_thang: { title: 'Title', body: nil} }
    assert_response :success
    assert_equal "Unable to create Title: body can't be blank", flash[:danger]
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].errors.present?
  end

  test 'edit' do
    thang = Effective::Thang.create!(title: 'Title', body: 'Body')

    get edit_admin_thang_url(thang)
    assert_response :success
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].persisted?
  end

  test 'update valid' do
    thang = Effective::Thang.create!(title: 'Title', body: 'Body')

    patch admin_thang_url(thang), params: { effective_thang: { id: thang.id, title: 'Title2', body: 'Body2'} }
    assert_equal 'Successfully updated Title2', flash[:success]
    assert_redirected_to edit_admin_thang_path(thang)

    assert @controller.resource.kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].persisted?
  end

  test 'update invalid' do
    thang = Effective::Thang.create!(title: 'Title', body: 'Body')

    patch admin_thang_url(thang), params: { effective_thang: { id: thang.id, title: 'Title2', body: nil} }
    assert_response :success
    assert_equal "Unable to update Title2: body can't be blank", flash[:danger]
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].errors.present?
  end

  test 'destroy' do
    thang = Effective::Thang.create!(title: 'Title', body: 'Body')

    delete admin_thang_url(thang)
    assert_equal 'Successfully deleted Title', flash[:success]
    assert_redirected_to admin_thangs_path
  end

  test 'member action valid' do
    thang = Effective::Thang.create!(title: 'Title', body: 'Body')

    post approve_admin_thang_url(thang), params: { effective_thang: { id: thang.id, title: 'Title2', body: 'Body2'} }
    assert_equal 'Successfully approved Title2', flash[:success]
    assert_redirected_to edit_admin_thang_path(thang)

    assert @controller.resource.kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].persisted?
  end

  test 'member action invalid' do
    thang = Effective::Thang.create!(title: 'Title', body: 'Body')

    post approve_admin_thang_url(thang), params: { effective_thang: { id: thang.id, title: 'Title2', body: nil} }
    assert_equal "Unable to approve Title2: body can't be blank", flash[:danger]
    assert_redirected_to edit_admin_thang_path(thang)
  end

  test 'approve member action invalid from edit' do
    thang = Effective::Thang.create!(title: 'Title', body: 'Body')

    post approve_admin_thang_url(thang),
      params: { effective_thang: { title: 'Title2', body: nil} },
      headers: { 'Referer': edit_admin_thang_url(thang) }

    assert_response :success
    assert_equal "Unable to approve Title2: body can't be blank", flash[:danger]
    assert_match "<form", @response.body

    assert @controller.resource.kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].kind_of?(Effective::Thang)
    assert @controller.view_context.assigns['thang'].errors.present?
  end

  test 'collection action' do
    thang = Effective::Thang.create!(title: 'Title', body: 'Body')

    get report_admin_thangs_url(thang)
    assert_equal Effective::Thang.all.to_a, @controller.resources
    assert_equal [thang], @controller.view_context.assigns['thangs']
  end

end
