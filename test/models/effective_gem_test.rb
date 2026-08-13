require 'test_helper'

class EffectiveGemTest < ActiveSupport::TestCase
  setup do
    @gem = Module.new do
      def self.config_keys
        [:inherited, :overridden]
      end

      include EffectiveGem
    end

    @gem.setup(:effective) do |config|
      config.inherited = 'default'
      config.overridden = 'default'
    end
  end

  test 'namespaced config inherits default values' do
    @gem.setup(:tenant) { |config| config.overridden = 'tenant' }

    assert_equal 'default', @gem.config(:tenant)[:inherited]
    assert_equal 'tenant', @gem.config(:tenant)[:overridden]
  end

  test 'namespaced config can override a default with false' do
    @gem.setup(:tenant) { |config| config.inherited = false }

    assert_equal false, @gem.config(:tenant)[:inherited]
  end

  test 'namespaced config can override a default with nil' do
    @gem.setup(:tenant) { |config| config.inherited = nil }

    assert_nil @gem.config(:tenant)[:inherited]
  end

  test 'namespaced config writes do not change defaults' do
    @gem.setup(:tenant) { |config| config.inherited = 'tenant' }

    assert_equal 'default', @gem.config(:effective)[:inherited]
    assert_equal 'tenant', @gem.config(:tenant)[:inherited]
  end

  test 'namespaced config inherits changes to defaults' do
    @gem.setup(:tenant) { |_| }
    @gem.setup(:effective) { |config| config.inherited = 'changed' }

    assert_equal 'changed', @gem.config(:tenant)[:inherited]
  end

  test 'namespaced config rejects unsupported keys' do
    error = assert_raises(RuntimeError) do
      @gem.setup(:tenant) { |config| config.unsupported = true }
    end

    assert_match 'unsupported config keys: [:unsupported]', error.message
  end
end
