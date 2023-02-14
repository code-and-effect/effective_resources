module Effective
  module CrudController
    module Save

      # Based on the incoming params[:commit] or passed action. Merges all options.
      def commit_action(action = nil)
        config = self.submits()
        ons = self.ons()

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
        exception = nil

        begin
          ActiveRecord::Base.transaction do
            EffectiveResources.transaction(resource) do
              run_callbacks(:resource_before_save)

              if resource.public_send("#{save_action}!") == false
                raise Effective::ActionFailed.new("failed to #{action}")
              end

              yield if block_given?

              run_callbacks(:resource_after_save)

              success = true
            rescue Effective::ActionFailed => e
              exception = e   # Dont rollback
            end
          end
        rescue ActiveRecord::RecordInvalid => e
          exception = e
        rescue => e
          exception = e
          notify_exception(e, resource, action) unless e.class.name == 'RuntimeError'
        end

        if exception.present?
          Rails.logger.info "  \e[31m\e[1mFAILED\e[0m\e[22m" # bold red
          Rails.logger.info "  Unable to #{action} #{resource} - #{exception.class} #{exception}"
          exception.backtrace.first(5).each { |line| Rails.logger.info('  ' + line) }

          if resource.respond_to?(:restore_attributes) && resource.persisted?
            resource.restore_attributes(['status', 'state'])
          end

          flash.now[:danger] = resource_flash(:danger, resource, action, e: exception)

          if exception.kind_of?(ActiveRecord::StaleObjectError)
            flash.now[:danger] = "#{flash.now[:danger]} <a href='#', class='alert-link' onclick='window.location.reload(true); return false;'>reload page and try again</a>"
          end
        end

        run_callbacks(success ? :resource_after_commit : :resource_error)

        success
      end

      def notify_exception(exception, resource, action)
        if defined?(ExceptionNotifier)
          ExceptionNotifier.notify_exception(exception, env: request.env, data: { resource: resource, action: action })
        else
          raise(exception)
        end
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
