# ActsAsSlugged
#
# This module automatically generates slugs based on the :to_s field using a before_validation filter
#
# Mark your model with 'acts_as_slugged' make sure you have a string field :slug

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

      reloading = instance_variable_get(:@_effective_reloading)
      reloading ||= self.class.instance_variable_get(:@_effective_reloading)
      reloading ||= klass.instance_variable_get(:@_effective_reloading) if respond_to?(:klass)

      return find_by_id(args.first) if reloading

      find_by_slug(args.first) || raise(::ActiveRecord::RecordNotFound.new("Couldn't find #{name} with 'slug'=#{args.first}"))
    end

    def find_by_slug_or_id(*args)
      where(slug: args.first).or(where(id: args.first)).first
    end

  end

  # Instance Methods
  def build_slug
    slug = to_s.parameterize.downcase[0, 250]

    if self.class.excluded_slugs.include?(slug)
      slug = "#{slug}-#{self.class.name.demodulize.parameterize}"
    end

    if (count = self.class.where('slug ILIKE ?', "#{slug}%").count) > 0
      uid = (Time.zone.now.to_i - 1_500_000_000).to_s(36) # This is a unique 6 digit url safe string
      slug = "#{slug}-#{uid}"
    end

    slug
  end

  def to_param
    slug_was || slug
  end

  def to_global_id(**params)
    params[:tenant] = Tenant.current if defined?(Tenant)
    GlobalID.new(URI::GID.build(app: Rails.application.config.global_id.app, model_name: model_name, model_id: to_param, params: params))
  end

  def reload(options = nil)
    self.class.instance_variable_set(:@_effective_reloading, true)
    retval = super
    self.class.instance_variable_set(:@_effective_reloading, nil)
    retval
  end

end
