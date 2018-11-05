# ActsAsArchived
#
# Implements the stupid archived pattern
# All archived really means is it shouldn't be included in the default index or new views
# It should still be editable, deletable, etc

# To use the routes concern, In your routes.rb:
#
# Rails.application.routes.draw do
#   acts_as_archivable
#   resource :things, concern: :archivable
# end

module ActsAsArchived
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_archived(options = nil)
      raise 'must respond to archived' unless new().respond_to?(:archived)

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
      archived :boolean, permitted: false
    end
  end

  module ClassMethods
    def acts_as_archived?; true; end
  end

  # Instance methods
  def archive!
    update_column(:archived, true)
  end

  def unarchive!
    update_column(:archived, false)
  end

end

