class Thing < ApplicationRecord

  effective_resource do
    title       :string
    body        :text
  end

  validates :title, presence: true
  validates :body, presence: true

  def to_s
    title.presence || 'New Thing'
  end

  def approve!
    save!
  end

end
