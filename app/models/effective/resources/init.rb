module Effective
  module Resources
    module Init

      private

      def _initialize(obj)
        @input_name = _initialize_input_name(obj)
        @instance = obj if (klass && obj.instance_of?(klass))
        @relation = obj if (klass && obj.kind_of?(ActiveRecord::Relation))
      end

      def _initialize_input_name(input)

        case input
        when String ; input
        when Symbol ; input
        when Class  ; input.name
        when (ActiveRecord::Relation rescue false); input.klass
        when (ActiveRecord::Reflection::MacroReflection rescue false); input.name
        when (ActionDispatch::Journey::Route rescue false); input.defaults[:controller]
        when nil    ; raise 'expected a string or class'
        else        ; input.class.name
        end.to_s.underscore
      end

      # Lazy initialized
      def _initialize_written
        @written_attributes = []
        @written_belong_tos = []
        @written_scopes = []

        return unless File.exists?(model_file)

        Effective::CodeReader.new(model_file) do |reader|
          first = reader.index { |line| line == '# Attributes' }
          last = reader.index(from: first) { |line| line.start_with?('#') == false && line.length > 0 } if first

          if first && last
            @written_attributes = reader.select(from: first+1, to: last-1).map do |line|
              Effective::Attribute.parse_written(line).presence
            end.compact
          end

          @written_belong_tos = reader.select { |line| line.start_with?('belongs_to ') }.map do |line|
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
