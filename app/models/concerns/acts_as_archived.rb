# ActsAsArchived
#
# Implements the dumb archived pattern
# An archived object should not be displayed on index screens, or any related resource's #new pages
# effective_select (from the effective_bootstrap gem) is aware of this concern, and calls .unarchived and .archived appropriately when passed an ActiveRecord relation
# Use the cascade argument to cascade archived changes to any has_manys
#
# class Thing < ApplicationRecord
#   has_many :comments
#   acts_as_archivable cascade: :comments
# end

# Each controller needs its own archive and unarchive action.
# To simplify this, use the following route concern.
#
# In your routes.rb:
#
# Rails.application.routes.draw do
#   acts_as_archived
#
#   resource :things, concern: :acts_as_archived
#   resource :comments, concern: :acts_as_archived
# end
#
# and include Effective::CrudController in your resource controller

module ActsAsArchived
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_archived(cascade: [])
      # Make sure we respond to archived attribute
      # puts "WARNING: (acts_as_archived) expected #{name} to respond to archived" unless resource.respond_to?(:archived)

      # Parse options
      cascade = Array(cascade).compact

      if cascade.any? { |obj| !obj.kind_of?(Symbol) }
        raise 'expected cascade to be an Array of has_many symbols'
      end

      cascade.reject { |cascade| cascade.respond_to?(cascade) }.each do |cascade|
        puts "WARNING: (acts_as_archived) expected #{name} to respond to #{cascade}."
      end

      @acts_as_archived_options = { cascade: cascade }

      include ::ActsAsArchived
    end
  end

  module RoutesConcern
    def acts_as_archived
      concern :acts_as_archived do
        post :archive, on: :member
        post :unarchive, on: :member
      end
    end
  end

  included do
    scope :archived, -> { where(archived: true) }
    scope :unarchived, -> { where(archived: false) }

    effective_resource do
      archived :boolean,  permitted: false
    end

    acts_as_archived_options = @acts_as_archived_options
    self.send(:define_method, :acts_as_archived_options) { acts_as_archived_options }
  end

  module ClassMethods
    def acts_as_archived?; true; end
  end

  # Instance methods
  def archive!
    transaction do
      update!(archived: true) # Runs validations
      acts_as_archived_options[:cascade].each { |obj| public_send(obj).update_all(archived: true) }
    end
  end

  def unarchive!
    transaction do
      update_column(:archived, false) # Does not run validations
      acts_as_archived_options[:cascade].each { |obj| public_send(obj).update_all(archived: false) }
    end
  end

  def destroy
    archive!
  end

end

