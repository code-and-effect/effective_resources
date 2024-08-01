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
    def acts_as_slugged?; true; end

    def relation
      super.tap { |relation| relation.extend(FinderMethods) }
    end

    def excluded_slugs
      [
        "admin",
        "resources",
        "schema_migrations",
        "ar_internal_metadata",
        "active_storage_blobs",
        "active_storage_attachments",
        "active_storage_variant_records",
        "orders",
        "action_text_rich_texts",
        "order_items",
        "carts",
        "cart_items",
        "customers",
        "subscriptions",
        "products",
        "addresses",
        "qb_requests",
        "qb_tickets",
        "logs",
        "qb_logs",
        "qb_order_items",
        "qb_realms",
        "qb_receipts",
        "qb_receipt_items",
        "pages",
        "page_banners",
        "page_sections",
        "carousel_items",
        "posts",
        "email_templates",
        "statuses",
        "memberships",
        "membership_histories",
        "membership_statuses",
        "organizations",
        "applicant_educations",
        "applicant_experiences",
        "representatives",
        "applicant_endorsements",
        "applicant_equivalences",
        "applicant_course_areas",
        "applicant_course_names",
        "applicant_courses",
        "applicant_reviews",
        "documents",
        "classified_wizards",
        "committees",
        "committee_members",
        "committee_folders",
        "committee_files",
        "events",
        "event_tickets",
        "event_registrants",
        "event_products",
        "event_registrations",
        "event_notifications",
        "rings",
        "ring_wizards",
        "stamps",
        "stamp_wizards",
        "active_storage_extensions",
        "cpd_categories",
        "cpd_activities",
        "cpd_special_rules",
        "cpd_special_rule_mates",
        "cpd_statement_activities",
        "cpd_statements",
        "cpd_audit_levels",
        "cpd_audit_level_sections",
        "cpd_audit_level_questions",
        "cpd_audit_level_question_options",
        "cpd_audits",
        "cpd_audit_reviews",
        "cpd_audit_review_items",
        "cpd_audit_responses",
        "cpd_audit_response_options",
        "cpd_bulk_audits",
        "mailchimp_list_members",
        "chats",
        "chat_users",
        "chat_messages",
        "cpd_targets",
        "cpd_cycles",
        "event_addons",
        "mailchimp_lists",
        "reports",
        "report_columns",
        "report_scopes",
        "notifications",
        "alerts",
        "permalinks",
        "tags",
        "taggings",
        "pg_search_documents",
        "fees",
        "applicant_references",
        "classifieds",
        "notification_logs",
        "polls",
        "poll_notifications",
        "poll_questions",
        "poll_question_options",
        "ballots",
        "ballot_responses",
        "ballot_response_options",
        "cpd_rules",
        "cpd_metrics",
        "cpd_metric_rule_mates",
        "cpd_metric_statement_activity_mates",
        "membership_categories",
        "applicant_course_confirmations",
        "applicant_advisor_consents",
        "lares",
        "epr_cycles",
        "epr_projects",
        "epr_charts",
        "epr_chart_cells",
        "certificates",
        "firm_users",
        "users",
        "categories",
        "eprs",
        "epr_documents",
        "firms",
        "applicants",
        "fee_payments"
      ]
      #::ActiveRecord::Base.connection.tables.map { |x| x }.compact
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

    if (count = self.class.where(slug: slug).count) > 0
      uid = Time.zone.now.nsec.to_s(16) # This is a unique 7-8 digit url safe hex string
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
