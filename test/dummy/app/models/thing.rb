class Thing < ApplicationRecord

  acts_as_published

  effective_resource do
    title       :string
    body        :text

    date        :date
    datetime    :datetime
    integer     :integer
    price       :integer
    decimal     :decimal
    boolean     :boolean

    published_start_at  :datetime 
    published_end_at    :datetime

    timestamps
  end

  validates :title, presence: true
  validates :body, presence: true

  def to_s
    title.presence || 'New Thing'
  end

  def approve!
    save!
  end

  # The save_resource will rollback the transaction
  def create_invalid_resource!
    Thong.create!(title: 'Title', body: 'Body') # Valid one
    Thong.create!(title: 'Invalid') # Will raise an error
  end

  # The idea is that this would be a Log in a real app
  # The save_resource will allow Thong to be created and not rollback the transaction
  def create_valid_resource_and_return_false!
    Thong.create!(title: 'Title', body: 'Body')
    false
  end

end
