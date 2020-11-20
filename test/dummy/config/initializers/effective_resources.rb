EffectiveResources.setup do |config|
  config.authorization_method = Proc.new { |controller, action, resource| true }
end
