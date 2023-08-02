require 'test_helper'

class TranslationTest < ActiveSupport::TestCase
  test 'default locale' do
    assert_equal :en, I18n.locale
  end

  test 'translate string' do
    assert_equal 'Effective Resources', I18n.t('effective_resources.name')
    assert_equal 'Effective Resources', EffectiveResources.et('effective_resources.name')
    assert_equal 'Hello dummy world', EffectiveResources.et('hello') # From dummy en.yml
  end

  test 'raises a StandardError (500 error) if translate string missing' do
    error = nil

    missing = begin
      EffectiveResources.et('effective_resources.name_missing')
    rescue StandardError => e
      error = e
    end

    assert error.present?
    assert error.kind_of?(StandardError)
  end

  test 'translate active record model' do
    thing = Thing.new()

    assert_equal 'Cool Thing', EffectiveResources.et(thing)
    assert_equal 'Cool Thing Title', EffectiveResources.et(thing, :title)
  end

  test 'raises no error if translate active record missing' do
    thong = Thong.new()

    assert_equal 'Thong', EffectiveResources.et(thong)
    assert_equal 'Title', EffectiveResources.et(thong, :title)
  end

end
