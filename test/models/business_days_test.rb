require 'test_helper'
require 'holidays'

class BusinessDaysTest < ActiveSupport::TestCase
  test 'business days' do
    # Monday
    date = Time.zone.local(2020, 12, 21)
    assert EffectiveResources.business_day?(date)

    # Saturday
    date = Time.zone.local(2020, 12, 19)
    refute EffectiveResources.business_day?(date)

    # Sunday
    date = Time.zone.local(2020, 12, 20)
    refute EffectiveResources.business_day?(date)

    # Christmas
    # date = Time.zone.local(2020, 12, 25)
    # refute EffectiveResources.business_day?(date)
  end

  test 'date_advance' do
    # Tuesday
    date = Time.zone.local(2020, 12, 1)

    assert_equal date, EffectiveResources.advance_date(date, business_days: 0)
    assert_equal Time.zone.local(2020, 12, 2), EffectiveResources.advance_date(date, business_days: 1)
    assert_equal Time.zone.local(2020, 12, 3), EffectiveResources.advance_date(date, business_days: 2)
    assert_equal Time.zone.local(2020, 12, 4), EffectiveResources.advance_date(date, business_days: 3)

    # Dec 5th and 6th is Saturday and Sunday
    assert_equal Time.zone.local(2020, 12, 7), EffectiveResources.advance_date(date, business_days: 4)
    assert_equal Time.zone.local(2020, 12, 8), EffectiveResources.advance_date(date, business_days: 5)

    # 22 business days Dec 1 -> Jan 4
    # assert_equal Time.zone.local(2021, 1, 4), EffectiveResources.advance_date(date, business_days: 22)
  end

end
