module Effective
  module CrudController
    module Actions

      def index
        Rails.logger.info 'Processed by Effective::CrudController#index'

        EffectiveResources.authorize!(self, :index, resource_klass)
        @page_title ||= resource_plural_name.titleize

        self.resources ||= resource_scope.all

        if (datatable = resource_datatable_class).present?
          @datatable ||= datatable.new(resource_datatable_attributes)
          @datatable.view = view_context
        end

        run_callbacks(:resource_render)
      end

      def new
        Rails.logger.info 'Processed by Effective::CrudController#new'

        self.resource ||= resource_scope.new

        self.resource.assign_attributes(
          params.to_unsafe_h.except(:controller, :action, :id).select { |k, v| resource.respond_to?("#{k}=") }
        )

        if params[:duplicate_id]
          duplicate = resource_scope.find(params[:duplicate_id])
          EffectiveResources.authorize!(self, :show, duplicate)

          self.resource = duplicate_resource(duplicate)
          raise "expected duplicate_resource to return an unsaved new #{resource_klass} resource" unless resource.kind_of?(resource_klass) && resource.new_record?

          if (message = flash[:success].to_s).present?
            flash.delete(:success)
            flash.now[:success] = "#{message.chomp('.')}. Adding another #{resource_name.titleize} based on previous."
          end
        end

        EffectiveResources.authorize!(self, :new, resource)
        @page_title ||= "New #{resource_name.titleize}"

        run_callbacks(:resource_render)
      end

      def create
        Rails.logger.info 'Processed by Effective::CrudController#create'

        self.resource ||= resource_scope.new
        action = commit_action[:action]

        resource.assign_attributes(send(resource_params_method_name))
        resource.created_by = current_user if resource.respond_to?(:created_by=)

        EffectiveResources.authorize!(self, (action == :save ? :create : action), resource)
        @page_title ||= "New #{resource_name.titleize}"

        respond_to do |format|
          if save_resource(resource, action)
            request.format = :html if specific_redirect_path?

            format.html do
              flash[:success] ||= resource_flash(:success, resource, action)
              redirect_to(resource_redirect_path)
            end

            format.js do
              flash.now[:success] ||= resource_flash(:success, resource, action)
              reload_resource # create.js.erb
            end
          else
            flash.delete(:success)
            flash.now[:danger] ||= resource_flash(:danger, resource, action)

            run_callbacks(:resource_render)

            format.html { render :new }
            format.js {} # create.js.erb
          end
        end
      end

      def show
        Rails.logger.info 'Processed by Effective::CrudController#show'

        self.resource ||= resource_scope.find(params[:id])

        EffectiveResources.authorize!(self, :show, resource)
        @page_title ||= resource.to_s

        run_callbacks(:resource_render)
      end

      def edit
        Rails.logger.info 'Processed by Effective::CrudController#edit'

        self.resource ||= resource_scope.find(params[:id])

        EffectiveResources.authorize!(self, :edit, resource)
        @page_title ||= "Edit #{resource}"

        run_callbacks(:resource_render)
      end

      def update
        Rails.logger.info 'Processed by Effective::CrudController#update'

        self.resource ||= resource_scope.find(params[:id])
        action = commit_action[:action]

        EffectiveResources.authorize!(self, (action == :save ? :update : action), resource)
        @page_title ||= "Edit #{resource}"

        resource.assign_attributes(send(resource_params_method_name))
        resource.current_user = current_user if resource.respond_to?(:current_user=)

        respond_to do |format|
          if save_resource(resource, action)
            request.format = :html if specific_redirect_path?

            format.html do
              flash[:success] ||= resource_flash(:success, resource, action)
              redirect_to(resource_redirect_path)
            end

            format.js do
              flash.now[:success] ||= resource_flash(:success, resource, action)
              reload_resource # update.js.erb
            end
          else
            flash.delete(:success)
            flash.now[:danger] ||= resource_flash(:danger, resource, action)

            run_callbacks(:resource_render)

            format.html { render :edit }
            format.js { } # update.js.erb
          end
        end
      end

      def destroy
        Rails.logger.info 'Processed by Effective::CrudController#destroy'

        self.resource = resource_scope.find(params[:id])
        action = :destroy

        EffectiveResources.authorize!(self, action, resource)
        @page_title ||= "Destroy #{resource}"

        respond_to do |format|
          if save_resource(resource, action)
            request.format = :html if specific_redirect_path?(action)

            format.html do
              flash[:success] ||= resource_flash(:success, resource, action)
              redirect_to(resource_redirect_path(action))
            end

            format.js do
              flash.now[:success] ||= resource_flash(:success, resource, action)
              # destroy.js.erb
            end
          else
            flash.delete(:success)
            request.format = :html  # Don't run destroy.js.erb

            format.html do
              flash[:danger] = (flash.now[:danger].presence || resource_flash(:danger, resource, action))
              redirect_to(resource_redirect_path(action))
            end
          end
        end
      end

      def member_action(action)
        Rails.logger.info "Processed by Effective::CrudController#member_action"

        self.resource ||= resource_scope.find(params[:id])

        EffectiveResources.authorize!(self, action, resource)
        @page_title ||= "#{action.to_s.titleize} #{resource}"

        if request.get?
          run_callbacks(:resource_render); return
        end

        to_assign = (send(resource_params_method_name) rescue {})
        resource.assign_attributes(to_assign) if to_assign.present? && to_assign.permitted?

        resource.current_user = current_user if resource.respond_to?(:current_user=)

        respond_to do |format|
          if save_resource(resource, action)
            request.format = :html if specific_redirect_path?(action)

            format.html do
              flash[:success] ||= resource_flash(:success, resource, action)
              redirect_to(resource_redirect_path(action))
            end

            format.js do
              flash.now[:success] ||= resource_flash(:success, resource, action)
              reload_resource
              render_member_action(action)
            end
          else
            flash.delete(:success)
            flash.now[:danger] ||= resource_flash(:danger, resource, action)

            run_callbacks(:resource_render)

            format.html do
              if resource_edit_path && (referer_redirect_path || '').end_with?(resource_edit_path)
                @page_title ||= "Edit #{resource}"
                render :edit
              elsif resource_new_path && (referer_redirect_path || '').end_with?(resource_new_path)
                @page_title ||= "New #{resource_name.titleize}"
                render :new
              elsif resource_show_path && (referer_redirect_path || '').end_with?(resource_show_path)
                @page_title ||= resource_name.titleize
                render :show
              else
                @page_title ||= resource.to_s
                flash[:danger] = flash.now[:danger]
                redirect_to(referer_redirect_path || resource_redirect_path(action))
              end
            end

            format.js { render_member_action(action) }
          end
        end
      end

      def collection_action(action)
        Rails.logger.info 'Processed by Effective::CrudController#collection_action'

        action = action.to_s.gsub('bulk_', '').to_sym

        if params[:ids].present?
          self.resources ||= resource_scope.where(id: params[:ids])
        end

        if effective_resource.scope?(action)
          self.resources ||= resource_scope.public_send(action)
        end

        self.resources ||= resource_scope.all

        EffectiveResources.authorize!(self, action, resource_klass)
        @page_title ||= "#{action.to_s.titleize} #{resource_plural_name.titleize}"

        if request.get?
          run_callbacks(:resource_render); return
        end

        raise "expected all #{resource_name} objects to respond to #{action}!" if resources.to_a.present? && !resources.all? { |resource| resource.respond_to?("#{action}!") }

        successes = 0

        # No attributes are assigned or saved. We purely call action! on the resource

        ActiveRecord::Base.transaction do
          successes = resources.select do |resource|
            begin
              resource.public_send("#{action}!") if EffectiveResources.authorized?(self, action, resource)
            rescue => e
              false
            end
          end.length
        end

        render json: { status: 200, message: "Successfully #{action_verb(action)} #{successes} / #{resources.length} selected #{resource_plural_name}" }
      end
    end

    private

    # Which member javascript view to render: #{action}.js or effective_resources member_action.js
    def render_member_action(action)
      view = lookup_context.template_exists?(action, _prefixes) ? action : :member_action
      render(view, locals: { action: action })
    end

  end
end
