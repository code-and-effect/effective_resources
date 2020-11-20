require 'test_helper'

class ResourceDatatablesTest < ActiveSupport::TestCase
  test 'datatable actions' do
    Thing.create!(title: 'Thing', body: 'Body')

    resource = Effective::Resource.new('thing')
    assert_equal 'ThingsDatatable', resource.datatable_klass.to_s

    datatable = resource.datatable_klass.new().rendered
    assert datatable.kind_of?(ThingsDatatable)

    actions = datatable.actions_col_actions(datatable.columns[:_actions])
    assert actions['Show'].present?
    assert actions['Edit'].present?
    assert actions['Delete'].present?
  end

  test 'admin datatable actions' do
    resource = Effective::Resource.new('admin/thing')
    assert_equal 'Admin::ThingsDatatable', resource.datatable_klass.to_s

    datatable = resource.datatable_klass.new(namespace: 'admin').rendered
    assert datatable.kind_of?(Admin::ThingsDatatable)
    assert_equal 'admin', datatable.controller_namespace

    actions = datatable.actions_col_actions(datatable.columns[:_actions])

    assert actions['Show'].present?
    assert actions['Edit'].present?
    assert actions['Delete'].present?
    assert actions['Approve'].present?
    assert actions['Decline'].present?
  end

end
