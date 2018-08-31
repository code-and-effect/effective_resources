# EffectiveResource
#
# Mark your model with 'effective_resource'

module EffectiveResource
  extend ActiveSupport::Concern

  module ActiveRecord
    def effective_resource(options = nil, &block)
      return @_effective_resource unless block_given?

      include ::EffectiveResource
      @_effective_resource = Effective::Resource.new(self, &block)
    end
  end

  included do
  end

  module ClassMethods
  end

end

