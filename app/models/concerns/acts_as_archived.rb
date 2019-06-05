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
#   acts_as_archivable cascade: :comments, strategy: :archive|:archive_all|:active_job
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
    def acts_as_archived(cascade: [], strategy: :archive)

      cascade = Array(cascade).compact
      strategy = strategy

      if cascade.any? { |obj| !obj.kind_of?(Symbol) }
        raise 'expected cascade to be an Array of has_many symbols'
      end

      unless [:archive, :archive_all, :active_job].include?(strategy)
        raise 'expected strategy to be :archive, :archive_all, or :active_job'
      end

      @acts_as_archived_options = { cascade: cascade, strategy: strategy }

      include ::ActsAsArchived
    end
  end

  module CanCan
    def acts_as_archived(klass)
      raise "klass does not implement acts_as_archived" unless klass.respond_to?(:acts_as_archived?)

      can(:archive, klass) { |obj| !obj.archived? }
      can(:unarchive, klass) { |obj| obj.archived? }
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
    define_callbacks :archive, :unarchive  # ActiveSupport::Callbacks

    scope :archived, -> { where(archived: true) }
    scope :unarchived, -> { where(archived: [false, nil]) }

    effective_resource do
      archived :boolean, permitted: false
    end

    acts_as_archived_options = @acts_as_archived_options
    self.send(:define_method, :acts_as_archived_options) { acts_as_archived_options }
  end

  module ClassMethods
    def acts_as_archived?; true; end

    # before_archive(if: -> { persisted? })
    def before_archive(*filters, &blk)
      set_callback(:archive, :before, *filters, &blk)
    end

    def after_archive(*filters, &blk)
      set_callback(:archive, :after, *filters, &blk)
    end

    def before_unarchive(*filters, &blk)
      set_callback(:unarchive, :before, *filters, &blk)
    end

    def after_unarchive(*filters, &blk)
      set_callback(:unarchive, :after, *filters, &blk)
    end

    # after_commit(if: :just_archived?)
    # after_commit(if: :just_unarchived?)
  end

  # Instance methods
  def archive!
    return true if archived?

    strategy = acts_as_archived_options[:strategy]
    cascade = acts_as_archived_options[:cascade]

    transaction do
      run_callbacks :archive do
        update!(archived: true) # Runs validations

        if strategy == :archive_all
          cascade.each { |associated| public_send(associated).update_all(archived: true) }
        end

        if strategy == :archive
          cascade.each { |associated| Array(public_send(associated)).each { |resource| resource.archive! } }
        end
      end
    end

    if strategy == :active_job
      ActsAsArchivedArchiveJob.perform_later(self)
    end

    true
  end

  def unarchive!
    return true unless archived?

    strategy = acts_as_archived_options[:strategy]
    cascade = acts_as_archived_options[:cascade]

    transaction do
      run_callbacks :unarchive do
        update!(archived: false) # Runs validations

        if strategy == :archive_all
          cascade.each { |associated| public_send(associated).update_all(archived: false) }
        end

        if strategy == :archive
          cascade.each { |associated| Array(public_send(associated)).each { |resource| resource.unarchive! } }
        end
      end
    end

    if strategy == :active_job
      ActsAsArchivedUnarchiveJob.perform_later(self)
    end

    true
  end

  def destroy
    archive!
  end

  private

  def just_archived?
    previous_changes[:archived] && archived?
  end

  def just_unarchived?
    previous_changes[:archived] && !archived?
  end

end

