class CreateSearches < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :first_name
      t.string :last_name
    end

    create_table :simple_orders do |t|
      t.integer :user_id
      t.string :title
    end

    create_table :advanced_orders do |t|
      t.integer :user_id
      t.string :user_type
      t.string :title
    end

  end
end
