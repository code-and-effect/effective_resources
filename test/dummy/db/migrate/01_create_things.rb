class CreateThings < ActiveRecord::Migration[6.0]
  def change
    create_table :things do |t|
      t.string :title

      t.date :date
      t.datetime :datetime
      t.integer :integer
      t.integer :price
      t.decimal :decimal
      t.boolean :boolean

      t.text :body

      t.datetime :published_start_at
      t.datetime :published_end_at

      t.timestamps
    end
  end
end
