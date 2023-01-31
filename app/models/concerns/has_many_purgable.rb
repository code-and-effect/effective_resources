# HasManyPurgable
#
# Mark your model with 'has_many_purgable' or 'has_one_purgable' to allow any has_many or has_one to be purgable
# Pass 'has_many_purgable :files, :avatar' to only allow the files and avatar to be purged.
# Works with effective_bootstrap file_field to display a Delete file on save checkbox
# to submit a _purge_attached array or association names to purge.

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

    attr_accessor :_purge_attached

    with_options(if: -> { _purge_attached.present? }) do
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

    associations = self.class.reflect_on_all_associations
      .select { |ass| ass.class_name == 'ActiveStorage::Attachment' }
      .map { |ass| ass.name.to_s.chomp('_attachments').chomp('_attachment').to_sym }

    names == :all ? associations : (names & associations)
  end

  private

  # As submitted by the form and permitted by our associations and options
  def has_many_purgable_attachments
    submitted = (Array(_purge_attached) - [nil, '', '0', ' ', 'false', 'f', 'off']).map(&:to_sym)
    submitted & has_many_purgable_names
  end

  def has_many_purgable_mark_for_destruction
    has_many_purgable_attachments.each do |name|
      Array(public_send(name)).each { |attachment| attachment.mark_for_destruction }
    end

    true
  end

  def has_many_purgable_purge
    has_many_purgable_attachments.each do |name|
      Rails.logger.info "[has_many_purgable] Purging #{name} attachments"
      Array(public_send(name)).each { |attachment| attachment.purge }
    end

    true
  end

end
