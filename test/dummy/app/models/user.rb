class User < ApplicationRecord
  effective_devise_user

  has_many :simple_orders
  has_many :advanced_orders, as: :user # Polymorphic

  effective_resource do
    first_name  :string
    last_name   :string
  end

  validates :first_name, presence: true
  validates :last_name, presence: true

  def to_s
    first_name.presence || 'New User'
  end

end
