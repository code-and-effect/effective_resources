module Effective
  module CrudController
    module PermittedParams
      BLACKLIST = [:created_at, :updated_at]

      # This is only available to models that use the effective_resource do ... end attributes block
      # It will be called last, and only for those resources
      # params.require(effective_resource.name).permit!
      def resource_permitted_params
        raise 'expected resource class to have effective_resource do .. end' if effective_resource.model.blank?

        permitted_params = effective_resource.permitted_attributes.select do |name, (datatype, atts)|
          if BLACKLIST.include?(name)
            false
          elsif atts.blank? || !atts.key?(:permitted)
            true # Default is true
          else
            permitted = (atts[:permitted].respond_to?(:call) ? instance_exec(&atts[:permitted]) : atts[:permitted])

            if [false, true, nil].include?(permitted)
              permitted || false
            elsif permitted == :blank
              effective_resource.namespaces.length == 0
            else # A symbol, string, or array of, representing the namespace
              (effective_resource.namespaces & Array(permitted).map(&:to_s)).present?
            end
          end
        end.keys

        if Rails.env.development?
          Rails.logger.info "Effective::CrudController#resource_permitted_params:"
          Rails.logger.info permitted_params
        end

        params.require(effective_resource.name).permit(*permitted_params)
      end

    end
  end
end
