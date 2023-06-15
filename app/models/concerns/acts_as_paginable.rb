#
# ActsAsPaginable
#
# Adds the a `paginate` scope to a model for `limit` and `offset` pagination.
#
module ActsAsPaginable
  extend ActiveSupport::Concern

  module Base
    def acts_as_paginable(options = nil)
      include ::ActsAsPaginable
    end
  end

  module ClassMethods
    def acts_as_paginable?; true; end
  end

  included do
    def self.default_per_page=(per_page)
      @default_per_page = per_page
    end

    def self.default_per_page
      @default_per_page || 12 # because we often do 3 columns of 4 elements layouts
    end

    scope :paginate, -> (page: nil, per_page: nil) {
      per_page = (per_page || default_per_page).to_i
      page = (page || 1).to_i
      offset = [(page - 1), 0].max * (per_page).to_i

      all.limit(per_page).offset(offset)
    }
  end
end
