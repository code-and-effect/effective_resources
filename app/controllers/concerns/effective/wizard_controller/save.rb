module Effective
  module WizardController
    module Save

      def render_next_step_if(method, resource, options = {})
        was_new_record = resource.new_record?

        # Run the save method
        success = (resource.send(method) rescue false)

        if !success
          Rails.logger.info resource.errors.inspect
          flash.now[:danger] = options.delete(:error) || "Errors occurred while trying to #{method}."
          render_step(wizard_value(step), options)
          return
        end

        # Success
        flash[:success] = options.delete(:success) || 'Successfully saved'
        @skip_to ||= next_step
        @redirect_to ||= resource_wizard_path(resource, @skip_to) if was_new_record
        yield if block_given?

        redirect_to(@redirect_to || wizard_path(@skip_to))
      end

    end
  end
end
