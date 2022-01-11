require 'test_helper'

class ResourceActionsTest < ActiveSupport::TestCase
  test 'thing routes' do
    resource = Effective::Resource.new('thing')
    assert_equal [:index, :create, :new, :edit, :show, :update, :destroy], resource.routes.keys

    resource = Effective::Resource.new('admin/things')
    assert_equal [:report, :approve, :decline, :index, :create, :new, :edit, :show, :update, :destroy], resource.routes.keys
  end

  test 'thing actions' do
    resource = Effective::Resource.new('thing')

    assert_equal [:index, :create, :new, :edit, :show, :update, :destroy], resource.actions
    assert_equal [:index, :create, :new, :edit, :show, :update, :destroy], resource.crud_actions

    assert_equal [:index, :create, :new], resource.collection_actions
    assert_equal [:index, :new], resource.collection_get_actions
    assert_equal [:create], resource.collection_post_actions

    assert_equal [:edit, :show, :update, :destroy], resource.member_actions
    assert_equal [:edit, :show], resource.member_get_actions
    assert_equal [:update], resource.member_post_actions
    assert_equal [:destroy], resource.member_delete_actions
  end

  test 'admin thing actions' do
    resource = Effective::Resource.new('admin/thing')

    assert_equal [:index, :create, :new, :edit, :show, :update, :destroy, :report, :approve, :decline], resource.actions
    assert_equal [:index, :create, :new, :edit, :show, :update, :destroy], resource.crud_actions

    assert_equal [:index, :create, :new, :report], resource.collection_actions
    assert_equal [:index, :new, :report], resource.collection_get_actions
    assert_equal [:create], resource.collection_post_actions

    assert_equal [:edit, :show, :update, :destroy, :approve, :decline], resource.member_actions
    assert_equal [:edit, :show], resource.member_get_actions
    assert_equal [:update, :approve, :decline], resource.member_post_actions
    assert_equal [:destroy], resource.member_delete_actions
  end

  test 'controller_path' do
    resource = Effective::Resource.new(Thing)
    assert_equal 'things', resource.controller_path

    resource = Effective::Resource.new(Thing, namespace: 'admin')
    assert_equal 'admin/things', resource.controller_path

    resource = Effective::Resource.new('thing')
    assert_equal 'thing', resource.controller_path

    resource = Effective::Resource.new('admin/thing')
    assert_equal 'admin/thing', resource.controller_path
  end

  test 'action_path_helper' do
    resource = Effective::Resource.new('thing')
    assert_equal 'things_path', resource.action_path_helper(:index)
    assert_equal 'new_thing_path', resource.action_path_helper(:new)
    assert_equal 'edit_thing_path', resource.action_path_helper(:edit)
    assert_equal 'thing_path', resource.action_path_helper(:show)

    resource = Effective::Resource.new('admin/things')
    assert_equal 'admin_things_path', resource.action_path_helper(:index)
    assert_equal 'new_admin_thing_path', resource.action_path_helper(:new)
    assert_equal 'edit_admin_thing_path', resource.action_path_helper(:edit)
    assert_equal 'admin_thing_path', resource.action_path_helper(:show)
  end

end
