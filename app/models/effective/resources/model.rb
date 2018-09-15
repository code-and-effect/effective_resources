module Effective
  module Resources
    module Model
      attr_accessor :model  # As defined by effective_resource do block in a model file

      def _initialize_model(&block)
        @model = ModelReader.new(&block)

        # If effective_developer is in live mode, this will cause it to refresh the class
        ActiveSupport.run_load_hooks(:effective_resource, self)
      end

      def model
        @model || (klass.effective_resource.model if klass.respond_to?(:effective_resource) && klass.effective_resource)
      end

    end
  end
end




