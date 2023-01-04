require 'test_helper'

class SearchAttributeTest < ActiveSupport::TestCase
  test 'search strings' do
    thing1 = Thing.create!(title: 'one', body: 'body')
    thing2 = Thing.create!(title: 'two', body: 'body')
    thing3 = Thing.create!(title: 'three', body: 'body')

    search = Effective::Resource.new(Thing).search(:title, 'one', operation: :eq)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:title, 'one', operation: :not_eq)
    assert_equal [thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:title, 'o', operation: :matches)
    assert_equal [thing1, thing2], search.to_a

    search = Effective::Resource.new(Thing).search(:title, 'o', operation: :starts_with)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:title, 'o', operation: :ends_with)
    assert_equal [thing2], search.to_a

    search = Effective::Resource.new(Thing).search(:title, 'o', operation: :does_not_match)
    assert_equal [thing3], search.to_a
  end

  test 'search integers' do
    thing1 = Thing.create!(title: 'one', body: 'body', integer: 1)
    thing2 = Thing.create!(title: 'two', body: 'body', integer: 2)
    thing3 = Thing.create!(title: 'three', body: 'body', integer: 3)

    search = Effective::Resource.new(Thing).search(:integer, 1, operation: :eq)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:integer, '1', operation: :eq)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:integer, 1, operation: :not_eq)
    assert_equal [thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:integer, 1, operation: :gt)
    assert_equal [thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:integer, 1, operation: :lt)
    assert_equal [], search.to_a
  end

  test 'search prices' do
    thing1 = Thing.create!(title: 'one', body: 'body', price: 100_00)
    thing2 = Thing.create!(title: 'two', body: 'body', price: 200_00)
    thing3 = Thing.create!(title: 'three', body: 'body', price: 300_00)

    search = Effective::Resource.new(Thing).search(:price, 100_00, operation: :eq, as: :price)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:price, '100', operation: :eq, as: :price)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:price, '100.00', operation: :eq, as: :price)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:price, 100_00, operation: :not_eq, as: :price)
    assert_equal [thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:price, 100_00, operation: :gt, as: :price)
    assert_equal [thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:price, 100_00, operation: :lt, as: :price)
    assert_equal [], search.to_a
  end

  test 'search decimals' do
    thing1 = Thing.create!(title: 'one', body: 'body', decimal: 100.00)
    thing2 = Thing.create!(title: 'two', body: 'body', decimal: 200.00)
    thing3 = Thing.create!(title: 'three', body: 'body', decimal: 300.00)

    search = Effective::Resource.new(Thing).search(:decimal, 100.00, operation: :eq)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:decimal, '100.0', operation: :eq)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:decimal, '100', operation: :eq)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:decimal, 100.00, operation: :not_eq)
    assert_equal [thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:decimal, 100.00, operation: :gt)
    assert_equal [thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:decimal, 100.00, operation: :lt)
    assert_equal [], search.to_a
  end

  test 'search dates' do
    now = Time.zone.now.beginning_of_year

    thing1 = Thing.create!(title: 'one', body: 'body', date: now)
    thing2 = Thing.create!(title: 'two', body: 'body', date: now + 1.month)
    thing3 = Thing.create!(title: 'three', body: 'body', date: now + 2.month)

    search = Effective::Resource.new(Thing).search(:date, now, operation: :eq)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:date, now, operation: :not_eq)
    assert_equal [thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:date, now, operation: :gt)
    assert_equal [thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:date, now, operation: :lt)
    assert_equal [], search.to_a

    search = Effective::Resource.new(Thing).search(:date, now, operation: :gteq)
    assert_equal [thing1, thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:date, "#{now.year}-#{now.month}", operation: :eq)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:date, "#{now.year}", operation: :eq)
    assert_equal [thing1, thing2, thing3], search.to_a
  end

  test 'search booleans' do
    thing1 = Thing.create!(title: 'one', body: 'body', boolean: true)
    thing2 = Thing.create!(title: 'two', body: 'body', boolean: false)
    thing3 = Thing.create!(title: 'three', body: 'body', boolean: false)

    search = Effective::Resource.new(Thing).search(:boolean, true)
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:boolean, 'true')
    assert_equal [thing1], search.to_a

    search = Effective::Resource.new(Thing).search(:boolean, false)
    assert_equal [thing2, thing3], search.to_a

    search = Effective::Resource.new(Thing).search(:boolean, 'false')
    assert_equal [thing2, thing3], search.to_a
  end

end
