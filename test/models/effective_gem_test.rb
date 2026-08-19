require 'test_helper'

class EffectiveGemTest < ActiveSupport::TestCase
  setup do
    @gem = Module.new do
      def self.config_keys
        [:inherited, :overridden, :widget_class_name]
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

  test 'class name uses an explicit configured class' do
    @gem.setup(:tenant) { |config| config.widget_class_name = 'Configured::Widget' }

    assert_equal 'Configured::Widget', @gem.class_name('Tenant::Owner', :widgets)
  end

  test 'class name falls back to the effective class without Tenant' do
    assert_equal 'Effective::Widget', @gem.class_name('Tenant::Owner', :widgets)
  end

  test 'class name discovers a tenant class when Tenant is defined' do
    tenant = Class.new
    tenant.const_set(:Widget, Class.new)
    Object.const_set(:Tenant, tenant)

    assert_equal 'Tenant::Widget', @gem.class_name('Tenant::Owner', :widgets)
  ensure
    Object.send(:remove_const, :Tenant) if defined?(Tenant)
  end

  test 'klass discovers the current tenant class' do
    tenant = Class.new do
      def self.current
        :example
      end
    end

    example = Module.new
    widget = Class.new
    example.const_set(:Widget, widget)
    Object.const_set(:Tenant, tenant)
    Object.const_set(:Example, example)

    assert_equal widget, @gem.klass(:widget)
  ensure
    Object.send(:remove_const, :Example) if defined?(Example)
    Object.send(:remove_const, :Tenant) if defined?(Tenant)
  end

  test 'klass can skip the effective fallback' do
    assert_nil @gem.klass(:widget, skip_fallback: true)
    assert_raises(NameError) { @gem.klass(:widget) }
  end
end
