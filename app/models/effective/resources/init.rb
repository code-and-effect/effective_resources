module Effective
  module Resources
    module Init

      private

      def _initialize(input)
        @input_name = _initialize_input_name(input)
      end

      def _initialize_input_name(input)
        case input
        when String ; input
        when Class  ; input.name
        when nil    ; raise 'expected a string or class'
        else        ; input.class.name
        end.downcase
      end

    end
  end
end
