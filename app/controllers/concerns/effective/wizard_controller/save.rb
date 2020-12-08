module Effective
  module WizardController
    module Save

      def save_wizard_resource(resource, action = nil, options = {})
        was_new_record = resource.new_record?
        action ||= resource.respond_to?("#{step}!") ? step : :save

        if save_resource(resource, action)
          flash[:success] = options.delete(:success) || resource_flash(:success, resource, action)

          @skip_to ||= next_step
          @redirect_to ||= resource_wizard_path(resource, @skip_to) if was_new_record

          redirect_to(@redirect_to || wizard_path(@skip_to))
        else
          flash.now[:danger] = options.delete(:error) || resource_flash(:danger, resource, action)
          render_step(wizard_value(step), options)
        end
      end

    end
  end
end
