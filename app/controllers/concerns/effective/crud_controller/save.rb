module Effective
  module CrudController
    module Save

      # Based on the incoming params[:commit] or passed action. Merges all options.
      def commit_action(action = nil)
        #config = (['create', 'update'].include?(params[:action]) ? self.class.submits : self.class.buttons)

        config = self.class.submits
        ons = self.class.ons

        commit = config[params[:commit].to_s]
        commit ||= config.find { |_, v| v[:action] == action }.try(:last)
        commit ||= config.find { |_, v| v[:action] == :save }.try(:last) if [nil, :create, :update].include?(action)
        commit ||= { action: (action || :save) }

        on = ons[params[:commit].to_s] || ons[action] || ons[commit[:action]]

        on.present? ? commit.reverse_merge(on) : commit
      end

      # This calls the appropriate member action, probably save!, on the resource.
      def save_resource(resource, action = :save, &block)
        save_action = ([:create, :update].include?(action) ? :save : action)
        raise "expected @#{resource_name} to respond to #{save_action}!" unless resource.respond_to?("#{save_action}!")

        if respond_to?(:current_user) && resource.respond_to?(:current_user=)
          resource.current_user ||= current_user
        end

        success = false

        EffectiveResources.transaction(resource) do
          begin
            run_callbacks(:resource_before_save)

            if resource.public_send("#{save_action}!") == false
              raise Effective::ActionFailed.new("failed to #{action}")
            end

            yield if block_given?

            run_callbacks(:resource_after_save)

            success = true
          rescue => e
            if Rails.env.development?
              Rails.logger.info "  \e[31m\e[1mFAILED\e[0m\e[22m" # bold red
              Rails.logger.info "  Unable to #{action} #{resource} - #{e.class} #{e}"
              e.backtrace.first(5).each { |line| Rails.logger.info('  ' + line) }
            end

            if resource.respond_to?(:restore_attributes) && resource.persisted?
              resource.restore_attributes(['status', 'state'])
            end

            flash.now[:danger] = resource_flash(:danger, resource, action, e: e)

            case e
            when ActiveRecord::StaleObjectError
              flash.now[:danger] = "#{flash.now[:danger]} <a href='#', class='alert-link' onclick='window.location.reload(true); return false;'>reload page and try again</a>"
              raise(ActiveRecord::Rollback) # This is a soft error, we want to display the flash message to user
            when Effective::ActionFailed, ActiveRecord::RecordInvalid, RuntimeError
              raise(ActiveRecord::Rollback) # This is a soft error, we want to display the flash message to user
            else
              raise(e) # This is a real error that should be sent to 500. Client should not see the message.
            end
          end
        end

        run_callbacks(success ? :resource_after_commit : :resource_error)

        success
      end

      def resource_flash(status, resource, action, e: nil)
        submit = commit_action(action)
        message = submit[status].respond_to?(:call) ? instance_exec(&submit[status]) : submit[status]

        return message.gsub('@resource', resource.to_s) if message.present?
        return nil if message.blank? && submit.key?(status)

        case status
        when :success then flash_success(resource, action)
        when :danger then flash_danger(resource, action, e: e)
        else
          raise "unknown resource flash status: #{status}"
        end
      end

      def reload_resource
        self.resource.reload if resource.respond_to?(:reload)
      end

      # Should return a new resource based on the passed one
      def duplicate_resource(resource)
        return resource.duplicate if resource.respond_to?(:duplicate)
        return resource.duplicate! if resource.respond_to?(:duplicate!)
        return resource.deep_dup if resource.respond_to?(:deep_dup)
        resource.dup
      end

    end
  end
end
