class Thong < ApplicationRecord

  acts_as_wizard(start: 'Start', select: 'Select', finish: 'Finish')

  effective_resource do
    title       :string
    body        :text

    wizard_steps  :text, permitted: false
  end

  validates :title, presence: true
  validates :body, presence: true

  def to_s
    title.presence || 'New Thong'
  end

end
