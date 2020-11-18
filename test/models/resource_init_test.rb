require 'test_helper'

class ResourceInitTest < ActiveSupport::TestCase
  test 'init' do
    resource = Effective::Resource.new('thing')
    assert_equal Thing, resource.klass

    resource = Effective::Resource.new('things')
    assert_equal Thing, resource.klass

    resource = Effective::Resource.new('Thing')
    assert_equal Thing, resource.klass

    resource = Effective::Resource.new(Thing)
    assert_equal Thing, resource.klass

    resource = Effective::Resource.new(Thing.all)
    assert_equal Thing, resource.klass

    resource = Effective::Resource.new(Thing.where(title: 'asdf'))
    assert_equal Thing, resource.klass

    resource = Effective::Resource.new(Thing.new(title: 'asdf'))
    assert_equal Thing, resource.klass
  end

  test 'init namespaces' do
    resource = Effective::Resource.new('admin/thing')
    assert_equal Thing, resource.klass
    assert_equal ['admin'], resource.namespaces

    resource = Effective::Resource.new('admin/things')
    assert_equal Thing, resource.klass
    assert_equal ['admin'], resource.namespaces

    resource = Effective::Resource.new('things', namespace: 'admin')
    assert_equal Thing, resource.klass
    assert_equal ['admin'], resource.namespaces

    resource = Effective::Resource.new('admin/things', namespace: 'admin')
    assert_equal Thing, resource.klass
    assert_equal ['admin'], resource.namespaces
  end

  test 'init relation' do
    resource = Effective::Resource.new(Thing.where(title: 'asdf'))
    assert_equal Thing, resource.klass
    assert_equal [], resource.namespaces
    assert_equal Thing.where(title: 'asdf'), resource.relation
  end

  test 'init instance' do
    thing = Thing.new(title: 'asdf')
    resource = Effective::Resource.new(thing)
    assert_equal Thing, resource.klass
    assert_equal thing, resource.instance
  end

end
