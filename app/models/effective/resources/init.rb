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

      # Lazy initialized
      def _initialize_written
        @written_attributes = []
        @written_belongs_tos = []
        @written_scopes = []

        Effective::CodeReader.new(model_file) do |reader|
          first = reader.index { |line| line == '# Attributes' }
          last = reader.index(from: first) { |line| line.start_with?('#') == false && line.length > 0 } if first

          if first && last
            @written_attributes = reader.select(from: first+1, to: last-1).map do |line|
              Effective::Attribute.parse(line).presence
            end.compact
          end

          @written_belongs_tos = reader.select { |line| line.start_with?('belongs_to ') }.map do |line|
            line.scan(/belongs_to\s+:(\w+)/).flatten.first
          end

          @written_scopes = reader.select { |line| line.start_with?('scope ') }.map do |line|
            line.scan(/scope\s+:(\w+)/).flatten.first
          end
        end
      end

    end
  end
end
