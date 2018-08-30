module Effective
  module Resources
    module Model
      attr_accessor :model  # As defined by effective_resource do block in a model file

      def _initialize_model(&block)
        @model = ModelReader.new(&block)
      end

      def model_attributes
        @model.try(:attributes) || {}
      end

    end
  end
end




