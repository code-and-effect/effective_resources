# HasManyPurgable
#
# Mark your model with 'has_many_purgable' or 'has_one_purgable' (both the same thing)
# to allow any has_many_attached or has_one_attached to be purgable.
#
# Pass 'has_many_purgable :files, :avatar' to only allow the files and avatar to be purged.
#
# Works with effective_bootstrap file_field, which renders a Remove button per attachment
# that submits the attachment's signed_id in the _purge array.
#
# You must permit the attribute _purge: []

module HasManyPurgable
  extend ActiveSupport::Concern

  module Base
    def has_many_purgable(*args)
      options = args.extract_options!
      names = Array(args).compact.presence || :all

      @has_many_purgable_options = options.merge(names: names)

      include ::HasManyPurgable
    end

    def has_one_purgable(*args)
      has_many_purgable(*args)
    end

  end

  included do
    options = @has_many_purgable_options
    self.send(:define_method, :has_many_purgable_options) { options }

    attr_accessor :_purge

    effective_resource do
      _purge  :permitted_param
    end

    with_options(if: -> { _purge.present? }) do
      before_validation { has_many_purgable_mark_for_destruction }
      after_save { has_many_purgable_purge }
    end

  end

  module ClassMethods
    def has_many_purgable?; true; end
  end

  # All the possible names, merging the actual associations and the given options
  def has_many_purgable_names
    names = has_many_purgable_options.fetch(:names)
    associations = self.class.attachment_reflections.keys.map(&:to_sym)
    names == :all ? associations : (names & associations)
  end

  private

  # Returns the ActiveStorage::Attachment records selected for purging, matched by signed_id.
  def has_many_purgable_attachments
    submitted = Array(_purge) - [nil, '', '0', ' ', 'false', 'f', 'off']
    return [] if submitted.blank?

    all_attachments = has_many_purgable_names.flat_map { |name| Array(public_send(name)) }
    all_attachments.select { |attachment| submitted.include?(attachment.signed_id) }
  end

  def has_many_purgable_mark_for_destruction
    has_many_purgable_attachments.each do |attachment|
      attachment.mark_for_destruction unless attachment.new_record?
    end

    true
  end

  def has_many_purgable_purge
    has_many_purgable_attachments.each do |attachment|
      Rails.logger.info "[has_many_purgable] Purging attachment #{attachment.id} (#{attachment.name})"
      attachment.purge if attachment.marked_for_destruction?
    end

    true
  end

end
