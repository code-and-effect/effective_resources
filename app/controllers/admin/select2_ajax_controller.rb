module Admin
  class Select2AjaxController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_resources) }

    include Effective::Select2AjaxController

    def users
      collection = current_user.class.all

      if collection.respond_to?(:to_select2)
        collection = collection.to_select2
      elsif collection.respond_to?(:sorted)
        collection = collection.sorted
      end

      respond_with_select2_ajax(collection) do |user|
        { id: user.to_param, text: user.try(:to_select2) || to_select2(user) }
      end
    end

    def organizations
      raise('the effective memberships gem is required') unless defined?(EffectiveMemberships)

      klass = EffectiveMemberships.Organization
      raise('an EffectiveMemberships.Organization is required') unless klass.try(:effective_memberships_organization?)

      collection = klass.all

      if collection.respond_to?(:to_select2)
        collection = collection.to_select2
      elsif collection.respond_to?(:sorted)
        collection = collection.sorted
      end

      respond_with_select2_ajax(collection) do |organization|
        { id: organization.to_param, text: organization.try(:to_select2) || to_select2(organization) }
      end
    end

    private

    def to_select2(resource)
      if resource.try(:email).present?
        "<span>#{resource}</span> <small>#{resource.email}</small>"
      else
        "<span>#{resource}</span>"
      end
    end

  end

end
