require 'test_helper'

class SearchAssociatedTest < ActiveSupport::TestCase
  test 'search belongs_to' do
    user1 = User.create!(first_name: 'First', last_name: 'Last')
    user2 = User.create!(first_name: 'Second', last_name: 'Last')

    order1 = SimpleOrder.create!(user: user1, title: 'First')
    order2 = SimpleOrder.create!(user: user2, title: 'Second')

    search = Effective::Resource.new(SimpleOrder).search(:user, user1.id)
    assert_equal [order1], search.to_a

    search = Effective::Resource.new(SimpleOrder).search(:user, user1.id.to_s)
    assert_equal [order1], search.to_a

    search = Effective::Resource.new(SimpleOrder).search(:user, [user1.id, user2.id])
    assert_equal [order1, order2], search.to_a

    search = Effective::Resource.new(SimpleOrder).search(:user, 'First')
    assert_equal [order1], search.to_a

    search = Effective::Resource.new(SimpleOrder).search(:user, 'First', operation: :does_not_match)
    assert_equal [order2], search.to_a
  end

  test 'search belongs_to_polymorphic' do
    user1 = User.create!(first_name: 'First', last_name: 'Last')
    user2 = User.create!(first_name: 'Second', last_name: 'Last')

    order1 = AdvancedOrder.create!(user: user1, title: 'First')
    order2 = AdvancedOrder.create!(user: user2, title: 'Second')

    search = Effective::Resource.new(AdvancedOrder).search(:user, user1.id)
    assert_equal [order1], search.to_a

    search = Effective::Resource.new(AdvancedOrder).search(:user, user1.id.to_s)
    assert_equal [order1], search.to_a

    search = Effective::Resource.new(AdvancedOrder).search(:user, [user1.id, user2.id])
    assert_equal [order1, order2], search.to_a

    search = Effective::Resource.new(AdvancedOrder).search(:user, 'First')
    assert_equal [order1], search.to_a

    search = Effective::Resource.new(AdvancedOrder).search(:user, 'First', operation: :does_not_match)
    assert_equal [order2], search.to_a
  end

  test 'search has_many' do
    user1 = User.create!(first_name: 'First', last_name: 'Last')
    user2 = User.create!(first_name: 'Second', last_name: 'Last')

    order1 = SimpleOrder.create!(user: user1, title: 'First')
    order2 = SimpleOrder.create!(user: user1, title: 'First')

    order3 = SimpleOrder.create!(user: user2, title: 'Second')
    order4 = SimpleOrder.create!(user: user2, title: 'Second')

    search = Effective::Resource.new(User).search(:simple_orders, order1.id)
    assert_equal [user1], search.to_a

    search = Effective::Resource.new(User).search(:simple_orders, order1.id.to_s)
    assert_equal [user1], search.to_a

    search = Effective::Resource.new(User).search(:simple_orders, 'First')
    assert_equal [user1], search.to_a

    search = Effective::Resource.new(User).search(:simple_orders, 'First', operation: :does_not_match)
    assert_equal [user2], search.to_a
  end

  test 'search any' do
    user1 = User.create!(first_name: 'First', last_name: 'Boy')
    user2 = User.create!(first_name: 'Second', last_name: 'Girl')
    user3 = User.create!(first_name: 'First', last_name: 'Human')

    search = Effective::Resource.new(User).search_any('Boy')
    assert_equal [user1], search.to_a

    search = Effective::Resource.new(User).search_any('First Boy')
    assert_equal [user1], search.to_a

    search = Effective::Resource.new(User).search_any('Second')
    assert_equal [user2], search.to_a

    search = Effective::Resource.new(User).search_any('Girl')
    assert_equal [user2], search.to_a

    search = Effective::Resource.new(User).search_any('Second Girl')
    assert_equal [user2], search.to_a

    search = Effective::Resource.new(User).search_any('Second')
    assert_equal [user2], search.to_a

    search = Effective::Resource.new(User).search_any('First Human')
    assert_equal [user3], search.to_a

    search = Effective::Resource.new(User).search_any('First')
    assert_equal [user1, user3], search.to_a

    search = Effective::Resource.new(User).search_any('First AND Boy')
    assert_equal [user1], search.to_a

    search = Effective::Resource.new(User).search_any('First OR Boy')
    assert_equal [user1, user3], search.to_a

    search = Effective::Resource.new(User).search_any('First AND Human')
    assert_equal [user3], search.to_a

    search = Effective::Resource.new(User).search_any('First OR Human')
    assert_equal [user1, user3], search.to_a

    search = Effective::Resource.new(User).search_any('First OR Second OR Human')
    assert_equal [user1, user2, user3], search.to_a
  end

end
