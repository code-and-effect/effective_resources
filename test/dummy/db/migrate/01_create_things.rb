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

      t.string :job_status
      t.datetime :job_started_at
      t.datetime :job_ended_at
      t.text :job_error

      t.timestamps
    end
  end
end
