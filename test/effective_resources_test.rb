require 'test_helper'

class EffectiveResources::Test < ActiveSupport::TestCase
  test 'thing is valid' do
    assert Thing.create!(title: "Title", body: "Body")
  end

  test 'normalize page' do
    [2, '2'].each do |page|
      assert_equal 2, EffectiveResources.normalize_page(page)
    end

    [nil, ''].each do |page|
      assert_equal 1, EffectiveResources.normalize_page(page)
    end

    ['03', '2abc', 'invalid', 0, -1, [], {}, ActionController::Parameters.new(page: 2)].each do |page|
      assert_raises(ActiveRecord::RecordNotFound) do
        EffectiveResources.normalize_page(page)
      end
    end
  end

  test 'validate page' do
    assert_equal 1, EffectiveResources.validate_page!(1, collection_count: 0, per_page: 10)
    assert_equal 4, EffectiveResources.validate_page!(4, collection_count: 40, per_page: 10)
    assert_equal 5, EffectiveResources.validate_page!(5, collection_count: 41, per_page: 10)

    error = assert_raises(ActiveRecord::RecordNotFound) do
      EffectiveResources.validate_page!(5, collection_count: 40, per_page: 10)
    end

    assert_equal 'Page 5 does not exist', error.message

    assert_raises(ActiveRecord::RecordNotFound) do
      EffectiveResources.validate_page!(2, collection_count: 0, per_page: 10)
    end
  end
end
