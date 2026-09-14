require 'test_helper'

class EffectiveDeviseUserTest < ActiveSupport::TestCase

  test 'email uniqueness' do
    User.create!(first_name: "A", last_name: "User", email: "user@mail.com",  alternate_email: "alter@mail.com")

    user = User.new(first_name: "B", last_name: "User", email: "valid@mail.com")
    assert user.valid?

    user.email = "other@mail.com"
    assert user.valid?

    # primary email already in use in someone's primary email
    user.email = "user@mail.com"
    assert user.invalid?
    assert user.errors.added?(:email, 'has already been taken')

    # alternate email already in use by someone's primary email
    user.email = "any@mail.com"
    user.alternate_email = "user@mail.com"
    assert user.invalid?
    assert user.errors.added?(:alternate_email, 'has already been taken')

    # primary email already in use by someone's alternate email
    user.email = "alter@mail.com"
    user.alternate_email = nil
    assert user.invalid?
    assert user.errors.added?(:email, 'has already been taken')

    user.email = "any@mail.com"
    user.alternate_email = "alter@mail.com"
    assert user.invalid?
    assert user.errors.added?(:alternate_email, 'has already been taken')
  end

  test 'email and alternate_email must be different' do
    user = User.new(first_name: "A", last_name: "User", email: "one@example.com",  alternate_email: "one@example.com")
    refute user.valid?

    user.assign_attributes(alternate_email: 'two@example.com')
    assert user.valid?
  end

  test 'find_first_by_auth_conditions only falls back to alternate email for email lookups' do
    primary = User.create!(first_name: 'Primary', last_name: 'User', email: 'primary@example.com')
    alternate = User.create!(first_name: 'Alternate', last_name: 'User', email: 'alternate@example.com', alternate_email: 'other@example.com')

    parameter_filter = Object.new
    parameter_filter.define_singleton_method(:filter) { |conditions| conditions }
    adapter = Object.new
    adapter.define_singleton_method(:find_first) { |conditions| User.where(conditions).first }

    singleton_class = User.singleton_class
    singleton_class.define_method(:devise_parameter_filter) { parameter_filter }
    singleton_class.define_method(:to_adapter) { adapter }

    assert_equal primary, User.find_first_by_auth_conditions(email: primary.email)
    assert_equal alternate, User.find_first_by_auth_conditions(email: alternate.alternate_email)

    assert_nil User.find_first_by_auth_conditions(first_name: 'Missing')
    assert_nil User.find_first_by_auth_conditions({ email: alternate.alternate_email }, id: -1)
  ensure
    singleton_class&.remove_method(:devise_parameter_filter)
    singleton_class&.remove_method(:to_adapter)
  end

end
