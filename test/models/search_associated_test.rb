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
  end

  # test 'search belongs_to_polymorphic' do
  #   user1 = User.create!(first_name: 'First', last_name: 'Last')
  #   user2 = User.create!(first_name: 'Second', last_name: 'Last')

  #   order1 = AdvancedOrder.create!(user: user1, title: 'First')
  #   order2 = AdvancedOrder.create!(user: user2, title: 'Second')

  #   search = Effective::Resource.new(AdvancedOrder).search(:user, user1.id)
  #   assert_equal [order1], search.to_a

  #   search = Effective::Resource.new(AdvancedOrder).search(:user, user1.id.to_s)
  #   assert_equal [order1], search.to_a

  #   search = Effective::Resource.new(AdvancedOrder).search(:user, [user1.id, user2.id])
  #   assert_equal [order1, order2], search.to_a

  #   search = Effective::Resource.new(AdvancedOrder).search(:user, 'First')
  #   assert_equal [order1], search.to_a
  # end

end
