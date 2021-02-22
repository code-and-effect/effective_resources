# ActsAsSlugged
#
# This module automatically generates slugs based on the :to_s field using a before_validation filter
#
# Mark your model with 'acts_as_sluggable' make sure you have a string field :slug

module ActsAsSlugged
  extend ActiveSupport::Concern

  module Base
    def acts_as_slugged(options = nil)
      include ::ActsAsSlugged
    end
  end

  included do
    extend FinderMethods

    before_validation do
      assign_attributes(slug: build_slug) if slug.blank?
    end

    validates :slug,
      presence: true, uniqueness: true, exclusion: { in: excluded_slugs }, length: { maximum: 255 },
      format: { with: /\A[a-zA-Z0-9_-]*\z/, message: 'only _ and - symbols allowed. no spaces either.' }
  end

  module ClassMethods
    def relation
      super.tap { |relation| relation.extend(FinderMethods) }
    end

    def excluded_slugs
      ::ActiveRecord::Base.connection.tables.map { |x| x }.compact
    end
  end

  module FinderMethods
    def find(*args)
      return super unless args.length == 1
      return super if block_given?

      where(slug: args.first).or(where(id: args.first)).first || raise(::ActiveRecord::RecordNotFound.new("Couldn't find #{name} with 'slug'=#{args.first}"))
    end
  end

  # Instance Methods
  def build_slug
    slug = to_s.parameterize.downcase[0, 250]

    if self.class.excluded_slugs.include?(slug)
      slug = "#{slug}-#{self.class.name.demodulize.parameterize}"
    end

    if (count = self.class.where(slug: slug).count) > 0
      slug = "#{slug}-#{count+1}"
    end

    slug
  end

  def to_param
    slug_was || slug
  end

end
