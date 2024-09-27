#
# ActsAsPublished
#
# Adds published and draft scopes. Adds published? and draft? methods
#
# add_column :things, :published_start_at, :datetime
# add_column :things, :published_end_at, :datetime
#
module ActsAsPublished
  extend ActiveSupport::Concern

  module Base
    def acts_as_published(options = nil)
      include ::ActsAsPublished
    end
  end

  module ClassMethods
    def acts_as_published?; true; end
  end

  included do
    attr_writer :save_as_draft

    before_validation(if: -> { EffectiveResources.falsey?(@save_as_draft) && (@save_as_draft.present? || new_record?) }) do
      self.published_start_at ||= Time.zone.now
    end

    before_validation(if: -> { EffectiveResources.truthy?(@save_as_draft) }) do
      assign_attributes(published_start_at: nil, published_end_at: nil)
    end

    validate(if: -> { published_start_at.present? && published_end_at.present? }) do
      errors.add(:published_end_at, 'must be after the published start date') if published_end_at <= published_start_at
    end

    scope :draft, -> { 
      where(published_start_at: nil)
        .or(where(arel_table[:published_start_at].gt(Time.zone.now)))
        .or(where(arel_table[:published_end_at].lteq(Time.zone.now)))
    }

    scope :published, -> {
      (try(:unarchived) || all)
      .where(arel_table[:published_start_at].lteq(Time.zone.now))
      .where(published_end_at: nil).or(where(arel_table[:published_end_at].gteq(Time.zone.now)))
     }
  end

  # Instance Methods
  def published?
    return false if published_start_at.blank? || published_start_at > Time.zone.now
    return false if published_end_at.present? && published_end_at <= Time.zone.now
    return false if try(:archived?)

    true
  end

  def draft?
    return true if published_start_at.blank? || published_start_at > Time.zone.now
    return true if published_end_at.present? && published_end_at <= Time.zone.now
    false
  end

  # For the form
  def save_as_draft
    persisted? && published_start_at.blank? && published_end_at.blank?
  end

end
