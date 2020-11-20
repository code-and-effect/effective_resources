require 'test_helper'

class EffectiveResources::Test < ActiveSupport::TestCase
  test 'thing is valid' do
    assert Thing.create!(title: "Title", body: "Body")
  end
end
