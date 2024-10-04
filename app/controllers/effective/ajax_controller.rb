module Effective
  class AjaxController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)

    include Effective::Select2AjaxController

    def users
      EffectiveResources.authorize!(self, :users, :ajax)

      with_organizations = current_user.class.try(:effective_memberships_organization_user?)

      collection = current_user.class.all
      collection = collection.includes(:organizations) if with_organizations

      respond_with_select2_ajax(collection, skip_authorize: true) do |user|
        data = { first_name: user.first_name, last_name: user.last_name, email: user.email }

        if with_organizations
          data[:company] = user.organizations.first.try(:to_s)
          data[:organization_id] = user.organizations.first.try(:id)
          data[:organization_type] = user.organizations.first.try(:class).try(:name)
        end

        { 
          id: user.to_param, 
          text: to_select2(user, with_organizations),
          data: data
        }
      end
    end

    def organizations
      EffectiveResources.authorize!(self, :organizations, :ajax)

      raise('the effective memberships gem is required') unless defined?(EffectiveMemberships)

      klass = EffectiveMemberships.Organization
      raise('an EffectiveMemberships.Organization is required') unless klass.try(:effective_memberships_organization?)

      collection = klass.all

      respond_with_select2_ajax(collection) do |organization|
        data = { title: organization.title, email: organization.email }

        { 
          id: organization.to_param, 
          text: to_select2(organization),
          data: data
        }
      end
    end
  end
end
