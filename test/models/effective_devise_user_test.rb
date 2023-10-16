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

end
