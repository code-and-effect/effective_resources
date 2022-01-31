module Effective
  module WizardController
    module PermittedParams
      BLACKLIST = [
        :created_at, :updated_at,
        :token, :slug, :price,
        :logged_change_ids, :orders, :purchased_order_id,
        :status, :status_steps, :wizard_steps,
        :submitted_at, :completed_at, :reviewed_at, :approved_at, :declined_at, :purchased_at,
        :declined_reason
      ]

      def resource_permitted_params
        permitted_name = params.key?(effective_resource.name) ? effective_resource.name : effective_resource.resource_name
        params.require(permitted_name).except(BLACKLIST).permit!
      end
    end
  end
end
