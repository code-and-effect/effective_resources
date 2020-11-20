module Effective
  class Thang < ApplicationRecord

    effective_resource do
      title       :string
      body        :text
    end

    validates :title, presence: true
    validates :body, presence: true

    def to_s
      title.presence || 'New Thang'
    end

    def approve!
      save!
    end

  end
end
