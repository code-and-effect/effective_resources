module Effective
  module CrudController
    module Actions

      def index
        Rails.logger.info 'Processed by Effective::CrudController#index'

        EffectiveResources.authorize!(self, :index, resource_klass)
        @page_title ||= resource_human_plural_name

        self.resources ||= resource_scope.all if resource_scope.respond_to?(:all)
        @datatable = resource_datatable()

        run_callbacks(:resource_render)
      end

      def new
        Rails.logger.info 'Processed by Effective::CrudController#new'

        self.resource ||= resource_scope.new

        # Assign attributes from the query string
        to_assign = if view_context.respond_to?(:inline_datatable?) && view_context.inline_datatable?
          EffectiveDatatables.find(params[:_datatable_id], params[:_datatable_attributes]).attributes
        end

        to_assign ||= if params[resource_name].present? && params[resource_name].respond_to?(:to_unsafe_h)
          params[resource_name].to_unsafe_h
        end

        to_assign ||= if params[effective_resource_name].present? && params[effective_resource_name].respond_to?(:to_unsafe_h)
          params[effective_resource_name].to_unsafe_h
        end

        to_assign ||= if params.present?
          params.to_unsafe_h.except(:controller, :action, :id, :duplicate_id)
        end

        if to_assign.present?
          resource.assign_attributes(to_assign.select { |k, v| resource.respond_to?("#{k}=") })
        end

        # Duplicate if possible
        if params[:duplicate_id].present?
          duplicate = (resource_scope.find(params[:duplicate_id]) rescue false)
          duplicate ||= resource_scope.find_by_id(params[:duplicate_id])

          EffectiveResources.authorize!(self, :show, duplicate)

          self.resource = duplicate_resource(duplicate)

          unless resource.kind_of?(resource_scope.klass) && resource.new_record?
            raise "expected duplicate_resource to return an unsaved new #{resource_scope.klass} resource"
          end

          if (message = flash[:success].to_s).present?
            flash.delete(:success)
            flash.now[:success] = "#{message.chomp('.')}. Adding another #{resource_human_name} based on previous."
          end
        end

        EffectiveResources.authorize!(self, :new, resource)
        @page_title ||= "New #{resource_human_name}"

        run_callbacks(:resource_render)

        respond_to do |format|
          format.html { }
          format.js { render('new', formats: :js) }
        end
      end

      def create
        Rails.logger.info 'Processed by Effective::CrudController#create'

        self.resource ||= resource_scope.new
        action = (commit_action[:action] == :save ? :create : commit_action[:action])

        if respond_to?(:current_user) && resource.respond_to?(:current_user=)
          resource.current_user ||= current_user
        end

        if respond_to?(:current_user) && resource.respond_to?(:created_by=)
          resource.created_by ||= current_user
        end

        resource.assign_attributes(send(resource_params_method_name))

        EffectiveResources.authorize!(self, action, resource)
        @page_title ||= "New #{resource_human_name}"

        if save_resource(resource, action)
          respond_with_success(resource, action)
        else
          respond_with_error(resource, action)
        end
      end

      def show
        Rails.logger.info 'Processed by Effective::CrudController#show'

        self.resource ||= resource_scope.find(params[:id])

        EffectiveResources.authorize!(self, :show, resource)
        @page_title ||= resource.to_s

        run_callbacks(:resource_render)

        respond_to do |format|
          format.html { }
          format.js { render('show', formats: :js) }
        end
      end

      def edit
        Rails.logger.info 'Processed by Effective::CrudController#edit'

        self.resource ||= resource_scope.find(params[:id])

        EffectiveResources.authorize!(self, :edit, resource)
        @page_title ||= "Edit #{resource}"

        run_callbacks(:resource_render)

        respond_to do |format|
          format.html { }
          format.js { render('edit', formats: :js) }
        end
      end

      def update
        Rails.logger.info 'Processed by Effective::CrudController#update'

        self.resource ||= resource_scope.find(params[:id])
        action = (commit_action[:action] == :save ? :update : commit_action[:action])

        EffectiveResources.authorize!(self, action, resource)
        @page_title ||= "Edit #{resource}"

        if respond_to?(:current_user) && resource.respond_to?(:current_user=)
          resource.current_user ||= current_user
        end

        if respond_to?(:current_user) && resource.respond_to?(:updated_by=)
          resource.updated_by ||= current_user
        end

        resource.assign_attributes(send(resource_params_method_name))

        if save_resource(resource, action)
          respond_with_success(resource, action)
        else
          respond_with_error(resource, action)
        end
      end

      def destroy
        Rails.logger.info 'Processed by Effective::CrudController#destroy'

        if params[:ids].present?
          return collection_action(:destroy)
        end

        self.resource = resource_scope.find(params[:id])
        action = :destroy

        EffectiveResources.authorize!(self, action, resource)
        @page_title ||= "Destroy #{resource}"

        if save_resource(resource, action)
          respond_with_success(resource, action)
        else
          respond_with_error(resource, action)
        end
      end

      def member_action(action)
        Rails.logger.info "Processed by Effective::CrudController#member_action"

        self.resource ||= resource_scope.find(params[:id])

        EffectiveResources.authorize!(self, action, resource)
        @page_title ||= "#{action.to_s.titleize} #{resource}"

        if request.get?
          run_callbacks(:resource_render)

          respond_to do |format|
            format.html { }
            format.js do
              html_template = action if template_present?(action, format: :html)
              template = template_present?(action) ? action : 'member_action'

              render(template, formats: :js, locals: { action: action, html_template: html_template })
            end
          end

          return
        end

        to_assign = (send(resource_params_method_name) rescue {})
        resource.assign_attributes(to_assign) if to_assign.present? && to_assign.permitted?

        if save_resource(resource, action)
          respond_with_success(resource, action)
        else
          respond_with_error(resource, action)
        end
      end

      def collection_action(action)
        Rails.logger.info 'Processed by Effective::CrudController#collection_action'

        action = action.to_s.gsub('bulk_', '').to_sym

        if params[:ids].present?
          self.resources ||= resource_scope.where(id: params[:ids])
        end

        if request.get? && effective_resource.scope?(action)
          self.resources ||= resource_scope.public_send(action)
        end

        self.resources ||= resource_scope.all

        EffectiveResources.authorize!(self, action, resource_klass)
        @page_title ||= "#{action.to_s.titleize} #{resource_human_name}"

        if request.get?
          @datatable = resource_datatable()
          run_callbacks(:resource_render)

          view = lookup_context.template_exists?(action, _prefixes) ? action : :index
          render(view, locals: { action: action })
          return
        end

        raise "expected all #{resource_name} objects to respond to #{action}!" if resources.to_a.present? && !resources.all? { |resource| resource.respond_to?("#{action}!") }

        successes = 0

        # No attributes are assigned or saved. We purely call action! on the resource

        ActiveRecord::Base.transaction do
          successes = resources.select do |resource|
            begin
              resource.public_send("#{action}!") if EffectiveResources.authorized?(self, action, resource)
            rescue Exception => e
              false
            end
          end.length
        end

        render json: { status: 200, message: "Successfully #{action_verb(action)} #{successes} / #{resources.length} selected #{resource_human_plural_name.downcase}" }
      end
    end

  end
end
