class Post < ApplicationRecord

  acts_as_statused :draft, :submitted, :approved

  belongs_to :submitted_by, class_name: 'User', optional: true

  effective_resource do
    title       :string

    # Acts as Statused
    status                 :string, permitted: false
    status_steps           :text, permitted: false

    submitted_at  :datetime
    approved_at   :datetime

    timestamps
  end

  validates :title, presence: true
  validates :submitted_by, presence: true, if: -> { submitted? }

  def to_s
    title.presence || 'New Thing'
  end

  def submit!
    submitted!
  end

  def approve!
    approved!
  end

end
