class SimpleOrder < ApplicationRecord

  belongs_to :user

  effective_resource do
    title       :string
  end

  validates :title, presence: true

  def to_s
    title.presence || 'New Simple Order'
  end

end
