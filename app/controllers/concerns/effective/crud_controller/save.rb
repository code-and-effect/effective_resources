module Effective
  module CrudController
    module Save

      # Based on the incoming params[:commit] or passed action. Merges all options.
      def commit_action(action = nil)
        config = (['create', 'update'].include?(params[:action]) ? self.class.submits : self.class.buttons)

        commit = if action.present?
          config[action.to_s] || config.find { |_, v| v[:action] == action }.try(:last) || { action: action }
        else
          config[params[:commit].to_s] || config.find { |_, v| v[:action] == :save }.try(:last) || { action: :save }
        end

        commit.reverse_merge!(self.class.ons[commit[:action]]) if self.class.ons[commit[:action]]

        commit
      end

      # This calls the appropriate member action, probably save!, on the resource.
      def save_resource(resource, action = :save, &block)
        raise "expected @#{resource_name} to respond to #{action}!" unless resource.respond_to?("#{action}!")

        resource.current_user ||= current_user if resource.respond_to?(:current_user=)

        ActiveRecord::Base.transaction do
          begin
            if resource.public_send("#{action}!") == false
              raise("failed to #{action} #{resource}")
            end

            yield if block_given?

            run_callbacks(:resource_save)
            return true
          rescue => e
            Rails.logger.info "Failed to #{action}: #{e.message}" if Rails.env.development?

            if resource.respond_to?(:restore_attributes) && resource.persisted?
              resource.restore_attributes(['status', 'state'])
            end

            flash.delete(:success)
            flash.now[:danger] = flash_danger(resource, action, e: e)
            raise ActiveRecord::Rollback
          end
        end

        run_callbacks(:resource_error)
        false
      end

      def resource_flash(status, resource, action)
        submit = commit_action(action)
        message = submit[status].respond_to?(:call) ? instance_exec(&submit[status]) : submit[status]
        return message if message.present?

        case status
        when :success then flash_success(resource, action)
        when :danger then flash_danger(resource, action)
        else
          raise "unknown resource flash status: #{status}"
        end
      end

      def reload_resource
        self.resource.reload if resource.respond_to?(:reload)
      end

      # Should return a new resource based on the passed one
      def duplicate_resource(resource)
        resource.dup
      end

    end
  end
end
