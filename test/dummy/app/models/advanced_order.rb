class AdvancedOrder < ApplicationRecord

  belongs_to :user, polymorphic: true

  effective_resource do
    title       :string
  end

  validates :title, presence: true

  def to_s
    title.presence || 'New Advanced Order'
  end

end
