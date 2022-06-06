require 'test_helper'

class ResourceScopeTest < ActionDispatch::IntegrationTest
  test 'save resource valid' do
    get admin_things_url

    thing = Thing.new(title: 'Title', body: 'Body')
    assert @controller.save_resource(thing)
  end

  test 'save resource invalid' do
    get admin_things_url

    thing = Thing.new(title: 'Title')
    refute @controller.save_resource(thing)
  end

  # Should rollback transaction
  test 'save create invalid resource' do
    get admin_things_url

    before = Thong.all.count

    thing = Thing.new(title: 'Title', body: 'Body')
    refute @controller.save_resource(thing, :create_invalid_resource)

    assert_equal before, Thong.all.count
  end

  # Should not rollback transaction
  test 'save create valid resource and return false' do
    get admin_things_url

    before = Thong.all.count

    thing = Thing.new(title: 'Title', body: 'Body')
    refute @controller.save_resource(thing, :create_valid_resource_and_return_false)

    assert_equal (before + 1), Thong.all.count
  end

end
