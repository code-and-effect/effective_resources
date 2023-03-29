class CreatePosts < ActiveRecord::Migration[6.0]
  def change
    create_table :posts do |t|
      t.integer :submitted_by_id

      t.string :title

      t.string :status
      t.text :status_steps

      t.datetime :submitted_at
      t.datetime :approved_at
    end

  end
end
