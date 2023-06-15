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

  included do
    scope :paginate, -> (page: nil, per_page: nil) {
      page = (page || 1).to_i
      offset = [(page - 1), 0].max * per_page

      all.limit(per_page).offset(offset)
    }
  end
end
