module Effective
  module Resources
    module Model
      attr_accessor :model  # As defined by effective_resource do block in a model file

      def _initialize_model(&block)
        @model = ModelReader.new(&block)
      end

      def model
        @model || (klass.effective_resource.model if klass.respond_to?(:effective_resource))
      end

      def model_attributes
        model ? model.attributes : {}
      end

      def permitted_attributes
        bts = belong_tos_ids.inject({}) { |h, ass| h[ass] = [:integer]; h }
        bts.merge(model_attributes)
      end

    end
  end
end




